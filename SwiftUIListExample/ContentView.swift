//
//    DynamicListView.swift
//
//

import Combine
import SwiftUI

// MARK: - General Components

/// The data items of the list. Must contain index (row number) as a stored property
protocol ListDataItem {
    var index: Int { get set }
    init(index: Int)
    
    /// Fetch additional data of the item, possibly asynchronously
    func fetchData()
    
    /// Has the data been fetched?
    var dataIsFetched: Bool { get }
}

/// Generic data provider for the list
class ListDataProvider<Item: ListDataItem>: ObservableObject {
    /// - Parameters:
    ///   - itemBatchCount: Number of items to fetch in each batch. It is recommended to be greater than number of rows displayed.
    ///   - prefetchMargin: How far in advance should the next batch be fetched? Greater number means more eager.
    ///                     Sholuld be less than temBatchSize.
    init(itemBatchCount: Int = 20, prefetchMargin: Int = 3) {
        itemBatchSize = itemBatchCount
        self.prefetchMargin = prefetchMargin
        reset()
    }
    
    private let itemBatchSize: Int
    private let prefetchMargin: Int
    
    private(set) var listID: UUID = UUID()
    
    func reset() {
        list = []
        listID = UUID()
        fetchMoreItemsIfNeeded(currentIndex: -1)
    }
    
    @Published var list: [Item] = []
    
    /// Extend the list if we are close to the end, based on the specified index
    func fetchMoreItemsIfNeeded(currentIndex: Int) {
        guard currentIndex >= list.count - prefetchMargin else { return }
        let startIndex = list.count
        for currentIndex in startIndex ..< max(startIndex + itemBatchSize, currentIndex) {
            list.append(Item(index: currentIndex))
            list[currentIndex].fetchData()
        }
    }
}

/// The view for the list row
protocol DynamicListRow: View {
    associatedtype Item: ListDataItem
    var item: Item { get }
    init(item: Item)
}

/// The view for the dynamic list
struct DynamicList<Row: DynamicListRow>: View {
    @ObservedObject var listProvider: ListDataProvider<Row.Item>
    var body: some View {
        return
            List(0 ..< listProvider.list.count, id: \.self) { index in
                Row(item: self.listProvider.list[index])
                    .onAppear {
                        self.listProvider.fetchMoreItemsIfNeeded(currentIndex: index)
                }
            }
            .id(self.listProvider.listID)
    }
}

// MARK: - Dynamic List Example

struct SlowDataStore {
    static func getAmount(forIndex _: Int) -> AnyPublisher<Double, Never> {
        Just(Double.random(in: 0 ..< 1))
            .subscribe(on: DispatchQueue.global(qos: .background))
            .map { val in usleep(UInt32.random(in: 500_000 ..< 2_000_000)); return val }
            .eraseToAnyPublisher()
    }
}

final class MyDataItem: ListDataItem, ObservableObject {
    init(index: Int) {
        self.index = index
    }
    
    var dataIsFetched: Bool {
        amount != nil
    }
    
    var index: Int = 0
    
    @Published var amount: Double?
    
    var label: String {
        "Line \(index)"
    }
    
    private var dataPublisher: AnyCancellable?
    
    func fetchData() {
        if !dataIsFetched {
            dataPublisher = SlowDataStore.getAmount(forIndex: index)
                .receive(on: DispatchQueue.main)
                .sink { amount in
                    self.amount = amount
            }
        }
    }
}

struct MyListRow: DynamicListRow {
    init(item: MyDataItem) {
        self.item = item
    }
    
    @ObservedObject var item: MyDataItem
    @State var animatedAmount: Double?
    
    let graphAnimation = Animation.interpolatingSpring(stiffness: 30, damping: 8)
    
    var body: some View {
        HStack {
            Text(self.item.label)
                .frame(width: 60, alignment: .leading)
                .font(.callout)
            Text(self.item.amount == nil ? "Loading..." :
                String(format: "Amount: %.1f", self.item.amount!))
                .frame(width: 100, alignment: .leading)
                .font(.callout)
            GraphBar(amount: self.item.amount, animatedAmount: self.$animatedAmount)
        }
        .onReceive(self.item.$amount) { amount in
            if !self.item.dataIsFetched {
                withAnimation(self.graphAnimation) {
                    self.animatedAmount = amount
                }
            }
        }
        .onAppear {
            if self.item.dataIsFetched {
                withAnimation(self.graphAnimation) {
                    self.animatedAmount = self.item.amount
                }
            }
        }
    }
}

struct GraphBar: View {
    let amount: Double?
    @Binding var animatedAmount: Double?
    
    var color: Color {
        guard let theAmount = amount else { return Color.gray }
        switch theAmount {
            case 0.0 ..< 0.3: return Color.red
            case 0.3 ..< 0.7: return Color.yellow
            case 0.7 ... 1.0: return Color.green
            default: return Color.gray
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Capsule()
                    .frame(maxWidth: CGFloat(geometry.size.width * CGFloat(self.animatedAmount ?? 0)), maxHeight: 20)
                    .foregroundColor(self.color)
            }.frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
        }
    }
}

struct ContentView: View {
    var listProvider = ListDataProvider<MyDataItem>(itemBatchCount: 20, prefetchMargin: 3)
    var body: some View {
        VStack {
            DynamicList<MyListRow>(listProvider: listProvider)
            
            Button("Reset") {
                self.listProvider.reset()
            }
        }
    }
}

struct DynamicList_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.colorScheme, .dark)
    }
}
