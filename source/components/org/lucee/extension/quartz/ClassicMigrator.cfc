component {

    static {
        static.UNIX0 = createDate(1970, 1, 1, "UTC");
        static.BASE_DATE = createDate(1899, 12, 30); // Old scheduler base date
    }

    public static function hasTasks() {
    	cfschedule(action = "list", returnvariable = "local.tasks");
    	return tasks.recordcount>0;
    }

     public static function deleteTasks() {
		cfschedule(action = "list", returnvariable = "local.tasks");
		loop query = tasks {
			cfschedule(action = "delete", task = tasks.task);
		}
    }

    public static function translateTasksToJobs() {
        cfsetting(show = true);
        cfschedule(action = "list", returnvariable = "local.tasks");
        
        var jobs = [];
        
        loop query = tasks {
            var job = [:];
            job["label"] = tasks.task;
            job["url"] = tasks.url;
            job["pause"] = tasks.paused ?: false;
            
            // Handle numeric intervals (seconds)
            if (isNumeric(tasks.interval)) {
                var intervalSeconds = val(tasks.interval);
                var minutes = intervalSeconds / 60;
                var hours = minutes / 60;
                
                // Get start and end times
                var startTime = isDate(tasks.starttime) ? tasks.starttime : createTime(0, 0, 0);
                var endTime = isDate(tasks.endtime) ? tasks.endtime : createTime(23, 59, 59);
                
                // If interval is >= 1 hour and fits evenly into hours, use cron
                if (hours >= 1 && (intervalSeconds % 3600 == 0)) {
                    // Use cron for hourly intervals
                    var cronTime = timeFormat(startTime, "s m H");
                    var startHour = hour(startTime);
                    var endHour = isDate(tasks.endtime) ? hour(endTime) : 23;
                    var hourInterval = int(hours);
                    
                    // Build hour range properly
                    var hourRange = "";
                    if (hourInterval == 1) {
                        hourRange = "#startHour#-#endHour#";
                    } else {
                        hourRange = "#startHour#-#endHour#/#hourInterval#";
                    }
                    
                    job["cron"] = "#timeFormat(startTime, 's m')# #hourRange# * * ? *";
                    
                    // Add start/end dates for cron jobs too
                    if (isDate(tasks.startdate)) {
                        job["startAt"] = dateFormat(tasks.startdate, "YYYY-MM-DD");
                    }
                    if (isDate(tasks.enddate)) {
                        job["endAt"] = dateFormat(tasks.enddate, "YYYY-MM-DD");
                    }
                }
                else {
                    // Use interval for non-hourly or complex intervals
                    job["interval"] = intervalSeconds;
                    
                    // Add start date/time if specified
                    if (isDate(tasks.startdate) || isDate(tasks.starttime)) {
                        var startDate = isDate(tasks.startdate) ? tasks.startdate : static.UNIX0;
                        if (isDate(tasks.starttime)) {
                            job["startAt"] = dateFormat(startDate, "YYYY-MM-DD") & "T" & timeFormat(startTime, "HH:MM:SS");
                        } else {
                            job["startAt"] = dateFormat(startDate, "YYYY-MM-DD");
                        }
                    }
                    
                    // Add end date/time if specified
                    if (isDate(tasks.enddate)) {
                        var endDate = tasks.enddate;
                        if (isDate(tasks.endtime)) {
                            job["endAt"] = dateFormat(endDate, "YYYY-MM-DD") & "T" & timeFormat(endTime, "HH:MM:SS");
                        } else {
                            job["endAt"] = dateFormat(endDate, "YYYY-MM-DD");
                        }
                    }
                }
            }
            // Handle string intervals (daily, weekly, monthly, once)
            else {
                var dayOfWeekStr = "?";
                var dayOfMonth = "*";
                var cronTime = "0 0 0";
                var month = "*";
                var year = "*";
                
                // Get time from starttime
                if (isDate(tasks.starttime)) {
                    cronTime = timeFormat(tasks.starttime, "s m H");
                }
                
                // Handle different interval types
                if (tasks.interval == "daily") {
                    dayOfWeekStr = "?";
                    dayOfMonth = "*";
                }
                else if (tasks.interval == "weekly" && isDate(tasks.startdate)) {
                    // Fix: Calculate correct day of week
                    var startDateDayOfWeek = dayOfWeek(tasks.startdate);
                    dayOfWeekStr = dayOfWeekShortAsString(startDateDayOfWeek);
                    dayOfMonth = "?";
                }
                else if (tasks.interval == "monthly" && isDate(tasks.startdate)) {
                    dayOfWeekStr = "?";
                    dayOfMonth = day(tasks.startdate);
                }
                else if (tasks.interval == "once") {
                    // For "once" - could use cron or handle specially
                    if (isDate(tasks.startdate)) {
                        dayOfMonth = day(tasks.startdate);
                        month = month(tasks.startdate);
                        year = year(tasks.startdate);
                        dayOfWeekStr = "?";
                    }
                }
                
                // Build cron expression: seconds minutes hours day-of-month month day-of-week year
                job["cron"] = "#cronTime# #dayOfMonth# #month# #dayOfWeekStr# #year#";
                
                // Add start/end dates for reference
                if (isDate(tasks.startdate)) {
                    job["startAt"] = dateFormat(tasks.startdate, "YYYY-MM-DD");
                }
                if (tasks.interval != "once" && isDate(tasks.enddate)) {
                    job["endAt"] = dateFormat(tasks.enddate, "YYYY-MM-DD");
                }
            }
            arrayAppend(jobs, job);
        }
        
        // Output results
        // dump(var = tasks, label = "Original Tasks");
        // dump(var = jobs, label = "Migrated Jobs");
        // dump(var = serializeJson(tasks), label = "Original Tasks serialized");
        // dump(var = serializeJson(jobs), label = "Migrated Jobs serialized");

        return jobs;
    }
}