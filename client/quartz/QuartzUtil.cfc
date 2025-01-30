component {
    
    /**
     * Converts a cron expression into a human-readable format.
     *
     * @cronExpression The cron expression to convert (e.g., "0/5 * 9-17 ? * MON-FRI").
     * @return A human-readable string representing the cron expression (e.g., "Every 5 seconds, every minute, every hour between 9am and 17pm, no specific day of the month, every month, on Monday, Tuesday, Wednesday, Thursday, Friday").
     */
    public static function cronToReadable(cronExpression) {
        // Split the cron expression into its components
        var parts = ListToArray(cronExpression, " ");
        var readable = "";
        
        if (ArrayLen(parts) != 6) {
            return "Invalid cron expression";
        }
        
        // Handle seconds part
        var seconds = parts[1];
        if (seconds == "*") {
            readable &= "Every second";
        } else if (find("*/", seconds)) {
            readable &= "Every " & ListLast(seconds, "/") & " seconds";
        } else {
            readable &= "At second " & seconds;
        }
        readable &= ", ";
        
        // Handle minutes part
        var minutes = parts[2];
        if (minutes == "*") {
            readable &= "every minute";
        } else if (find("*/", minutes)) {
            readable &= "every " & ListLast(minutes, "/") & " minutes";
        } else {
            readable &= "at minute " & minutes;
        }
        readable &= ", ";
        
        // Handle hours part
        var hours = parts[3];
        if (hours == "*") {
            readable &= "every hour";
        } else if (find("-", hours)) {
            readable &= "every hour between " & ListFirst(hours, "-") & "am and " & ListLast(hours, "-") & "pm";
        } else {
            readable &= "at hour " & hours;
        }
        readable &= ", ";
        
        // Handle day of month part
        var dayOfMonth = parts[4];
        if (dayOfMonth == "*") {
            readable &= "every day of the month";
        } else if (dayOfMonth == "?") {
            readable &= "no specific day of the month";
        } else {
            readable &= "on day " & dayOfMonth;
        }
        readable &= ", ";
        
        // Handle month part
        var month = parts[5];
        if (month == "*") {
            readable &= "every month";
        } else {
            readable &= "in month " & month;
        }
        readable &= ", ";
        
        // Handle day of week part
        var dayOfWeek = parts[6];
        if (dayOfWeek == "*") {
            readable &= "every day of the week";
        } else if (dayOfWeek == "?") {
            readable &= "no specific day of the week";
        } else {
            var days = {
                "SUN": "Sunday",
                "MON": "Monday",
                "TUE": "Tuesday",
                "WED": "Wednesday",
                "THU": "Thursday",
                "FRI": "Friday",
                "SAT": "Saturday"
            };
            var readableDays = [];
            for (var day in ListToArray(dayOfWeek, ",")) {
                readableDays.append(days[day]);
            }
            readable &= "on " & ArrayToList(readableDays, ", ");
        }
        
        return readable;
    }
}