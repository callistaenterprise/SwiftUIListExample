# SwiftUIListExample
Sample code to complement an article about how to create Dynamic Lists With Asynchronous Data Loading in SwiftUI.

It demonstrates how to create a list that meets the following requirements.



1. The list should grow dynamically and batch-wise as the user scrolls
2. The data on each row is fetched from a (possibly) slow data source - must be possible to be performed asynchronously in the background
3. Some row data should be animated in two different situations: a) when data has been fetched and b) whenever a row becomes visible
4. Possibility to reset the list and reload data
5. Smooth scrolling throughout

Below is a simple video that shows an example of how the list should work.

[![Video](https://www.callistaenterprise.se/assets/blogg/swiftui/RPReplay_Final1587392731.png)](https://www.callistaenterprise.se/assets/blogg/swiftui/RPReplay_Final1587392731.mov " ")
