<cfinclude template="functions.cfm">
<cfscript>

    job = application.quartz.getTriggerForJob(url.name,url.group, true);
    dump(job);
</cfscript>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Job Details</title>
    <link rel="stylesheet" href="assets/default.css">
</head>
<body>
    <h2>Job Details</h2>
<cfoutput>
    <table class="schedule-table">
        <tbody>
            <tr>
                <td>Label</td>
                <td>#job.jobLabel#</td>
            </tr>
            <tr>
                <td>State</td>
                <td>#job.state#</td>
            </tr>
            <tr>
                <td>Previous Fire Time</td>
                <td><cfif isDate(job.previousFireTime)>#diffFormat(job.previousFireTime)#<cfelse>-</cfif></td>
            </tr>
            <tr>
                <td>Next Fire Time</td>
                <td><cfif isDate(job.nextFireTime)>#diffFormat(job.nextFireTime)#<cfelse>-</cfif></td>
            </tr>
            <tr>
                <td>Final Fire Time</td>
                <td><cfif isDate(job.finalFireTime)>#diffFormat(job.finalFireTime)#<cfelse>-</cfif></td>
            </tr>
            <tr>
                <td>Start Time</td>
                <td><cfif isDate(job.startTime)>#diffFormat(job.startTime)#<cfelse>-</cfif></td>
            </tr>
            <tr>
                <td>End Time</td>
                <td><cfif isDate(job.endTime)>#diffFormat(job.endTime)#<cfelse>-</cfif></td>
            </tr>
            <tr>
                <td>Schedule</td>
                <td>#job.scheduleTranslated#</td>
            </tr>
            <!-- Add more fields as needed -->
        </tbody>
    </table>
</cfoutput>
</body>
</html>
