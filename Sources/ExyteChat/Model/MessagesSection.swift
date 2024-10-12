//
//  Created by Alex.M on 08.07.2022.
//

import Foundation

struct MessagesSection: Equatable {

    let date: Date
    var rows: [MessageRow]

    init(date: Date, rows: [MessageRow]) {
        self.date = date
        self.rows = rows
    }

    var formattedDate: String {
        //mleavy
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        let dateWeek = Calendar.current.component(.weekOfYear, from: date)
        if currentWeek == dateWeek {
            let index = Calendar.current.component(.weekday, from: date) // this returns an Int
            let dayName = Calendar.current.weekdaySymbols[index - 1] // subtract 1 since the index starts at 1
            
            let relative = DateFormatter.relativeDateFormatter.string(from: date)
            if relative.contains(dayName) {
                return dayName
            }
            else {
                return relative
            }
        }
        else {
            return DateFormatter.relativeDateFormatter.string(from: date)
        }
    }

    static func == (lhs: MessagesSection, rhs: MessagesSection) -> Bool {
        lhs.date == rhs.date && lhs.rows == rhs.rows
    }

}
