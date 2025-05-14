<cfinclude template="functions.cfm">
<cfscript>
    name="quartz-task";
    state=GatewayState(name);
    count=10;
    while("starting"==state && count>0) {
        count--;
        sleep(100);
        state=GatewayState(name);
    }
    
    
    if("running"==state) {
        quartz=getQuartz(name);
        jobs = quartz.getTriggersAsQuery( false);
        meta=quartz.getMetadataAsStruct();
    }
</cfscript>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <cfoutput><title>Job Schedule #meta.version?:""# (#state#)</title></cfoutput>
    <link rel="stylesheet" href="assets/all.min.css">
    <link rel="stylesheet" href="assets/default.css?randon=<cfoutput>#createUniqueId()#</cfoutput>">
    <script>
        function jobAction(jobName, jobGroup, action) {
            var xhr = new XMLHttpRequest();
            xhr.open("POST", "action.cfm", true);
            xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");

            xhr.onreadystatechange = function () {
                if (xhr.readyState === 4 && xhr.status === 200) {
                    if (action === "edit") {
                        document.getElementById('jobConfigTextarea').value=xhr.responseText;
                        document.getElementById('jobConfigButton').innerText="Add / Update";

                        
                    }
                    else if (action === "copy") {
                        // Store the server response in the clipboard
                        navigator.clipboard.writeText(xhr.responseText).then(function() {
                            // Find the button that triggered the action and update its text
                            var button = document.querySelector(`button[onclick*="'${jobName}','${jobGroup}','copy'"]`);
                            if (button) {
                                var original = button.innerHTML;
                                button.innerHTML = '<i class="fa fa-check">';
                                
                                // Change back to original text after 5 seconds
                                setTimeout(function() {
                                    button.innerHTML = original;
                                }, 3000);
                            }
                        }).catch(function(error) {
                            console.error("Failed to copy: " + error);
                        });
                    }
                    else {
                        // Reload the page to update the job state for other actions
                        location.reload(); 
                    }
                }
            };
            if("add"==action) {
                var jobConfig = document.getElementById('jobConfigTextarea').value;
                xhr.send(jobConfig);
            }
            else xhr.send("name=" + encodeURIComponent(jobName) + "&group=" + encodeURIComponent(jobGroup)+ "&action=" + encodeURIComponent(action));
        }
    </script>
</head>
<body>
    <cfoutput><h1><!--- <img src="assets/logo.png">--->Quartz Job Scheduler #meta.version?:""# (#state#)</h1>
    
    <cfif state EQ "running">
        <p>Stop local representation of the Quartz Scheduler, that does not affect other server sharing the same job storage.</p>
        <button class="btn stop" onclick="jobAction('','', 'stop')">Stop</button>
        <button class="btn restart" onclick="jobAction('','', 'restart')">Restart</button>
    <cfelseif state EQ "stopped">
        <p>Start local representation of the Quartz Scheduler, that does not affect other server sharing the same job storage.</p>
     <button class="btn start" onclick="jobAction('','', 'start')">Start</button>
    </cfif>
    </cfoutput>
<cfif not isNull(quartz)>
    <cfoutput><h2>Jobs</h2></cfoutput>
    <table class="schedule-table">
        <thead>
            <tr>
                <th>Job</th>
                <th>Endpoint</th>
                <th>Schedule</th>
                <th>State</th>
                <th>Last Execution</th>
                <th>Next Execution</th>
                <th>Final Execution</th>
                <th>Start Time</th>
                <th>End Time</th>
                <th colspan="4">Actions</th>
            </tr>
        </thead>
        <tbody>
            <cfoutput query="jobs">
            <tr class="<cfif jobs.state EQ 'NORMAL'>normal<cfelseif jobs.state EQ 'PAUSED'>paused<cfelseif jobs.state EQ 'ERROR' OR jobs.state EQ 'BLOCKED'>error<cfelse>complete</cfif>">
                <td>#jobs.jobLabel#</td>
                <td>#jobs.endpoint#</td>
                <td>#jobs.schedule# #jobs.scheduleType=="interval"?" seconds":""#</td>
                <td>#jobs.state#</td>
                <td><cfif isDate(jobs.previousFireTime)>#diffFormat(jobs.previousFireTime)#<cfelse>-</cfif></td>
                <td><cfif jobs.state!="PAUSED" && isDate(jobs.nextFireTime)>#diffFormat(jobs.nextFireTime)#<cfelse>-</cfif></td>
                <td><cfif isDate(jobs.finalFireTime)>#diffFormat(jobs.finalFireTime)# <cfelse>-</cfif></td>
                <td><cfif isDate(jobs.startTime)>#diffFormat(jobs.startTime)#<cfelse>-</cfif></td>
                <td><cfif isDate(jobs.endTime)>#diffFormat(jobs.endTime)#<cfelse>-</cfif></td>
                <td>
                    <cfif jobs.state EQ 'NORMAL'>
                        <button title="Pause" class="btn pause" onclick="jobAction('#jobs.jobName#','#jobs.jobGroup#','pause')"><i class="fa fa-pause"></i></button>
                    <cfelseif jobs.state EQ 'PAUSED'>
                        <button title="Resume" class="btn resume" onclick="jobAction('#jobs.jobName#','#jobs.jobGroup#', 'resume')"><i class="fa fa-play"></i></button>
                    <cfelse>
                        -
                    </cfif>
                </td>
                <td>
                    <button title="Copy it" class="btn copy" onclick="jobAction('#jobs.jobName#','#jobs.jobGroup#','copy')"><i class="fa fa-copy"></i></button>
                </td>
                <td>
                    <button title="Edit it" class="btn edit" onclick="jobAction('#jobs.jobName#','#jobs.jobGroup#','edit')"><i class="fa fa-edit"></i></button>
                </td>
                <td>
                    <button title="Delete it" class="btn delete" onclick="jobAction('#jobs.jobName#','#jobs.jobGroup#','delete')"><i class="fa fa-trash"></i></button>
                </td>
            </tr>
            </cfoutput>
            <tr>
                <td colspan="13">
                    <textarea id="jobConfigTextarea">{
    "label": "every 5 seconds on work hours",
    "url": "/example.cfm",
    "cron": "0/5 * 9-17 ? * MON-FRI",
    "pause": false,
    "stateful": false
}</textarea>
                    <button id="jobConfigButton" class="btn add" onclick="jobAction('','','add')">Add</button>    
                    <div class="comment">
                        Note: You can use online tools to generate cron expressions. Just search for "cron expression generator" on Google. 
                        <br><br>
                        If the URL starts with "/", it will make a local call using the internalRequest function, meaning the job will run on the same server. 
                        If the URL is a full address like "http://localhost:8888/jobs/dummy.cfm", the job can run from any server, which is useful for distributed or external tasks.
                        <br><br>
                        <strong>Tip:</strong> You can add a single job by providing a JSON structure with the job details. To add multiple jobs at once, use an array of such structures, with each structure representing a different job. This allows you to efficiently set up multiple tasks in one go.
                    </div> </td>
            </tr>
        </tbody>
    </table>

    <cfoutput><h2>Info</h2>
    <table class="schedule-table">
       <thead>
           <tr>
            <th>Storage</th>
            <th>Started</th>
            <th>Jobs executed</th>
            <th>Version</th>
           </tr>
       </thead>
       <tr>
        <td >
            Type: #meta.jobStoreType#<br>
            Persistence: #yesNoFormat(meta.jobStoreSupportsPersistence)#<br>
            Clustered: #yesNoFormat(meta.jobStoreClustered)#
        </td>
        <td>#diffFormat(meta.runningSince)#</td>
        <td>#meta.numberOfJobsExecuted#</td>
        <td>#meta.version#</td>
       </tr>
       <tr>
        <td colspan="4">
            <div class="comment">#meta.summary#</div>
        </td>
       </tr>
   </tbody>
</table>
</cfoutput>

<!---
    <cfoutput>
        <h2>Development</h2>
<pre>#serializeJSON(var:quartz.exportJobs(),compact:false)#</pre>
<cfdump var="#jobs#" expand=false>
    </cfoutput>
--->
</cfif>
</body>
</html>
