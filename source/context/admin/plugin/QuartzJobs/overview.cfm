<cfoutput>
<style>
.schedule-textarea {
    width: 100%; /* Make textarea full width */
    height: 120px; /* Set a fixed height for consistency */
    resize: vertical; /* Allow vertical resizing */
    box-sizing: border-box; /* Include padding/border in element's width and height */
    margin-bottom: 10px; /* Space between textarea and button */
}
</style>
		<meta charset="UTF-8">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<link rel="stylesheet" href="assets/all.min.css">
		<link rel="stylesheet" href="assets/default.css?randon=<cfoutput>#createUniqueId()#</cfoutput>">
		<script>
function insertTemplate(type) {
    var textarea = document.getElementById('jobConfigTextarea');
    
    if (type === 'url') {
        textarea.value = `{
    "label": "call URL every 5 seconds on work hours",
    "slug": "example-every-5s",
    "url": "/example.cfm",
    "cron": "0/5 * 9-17 ? * MON-FRI",
    "pause": false,
    "stateful": false
}`;
    } else if (type === 'component') {
        textarea.value = `{
    "label": "call CFC every hour", 
    "component": "com.example.MyJobComponent",
    "cron": "0 0 * * * ? *",
    "pause": false,
    "stateful": false
}`;
    } else if (type === 'daily') {
        textarea.value = `{
    "label": "call external URL daily at 17:32",
    "url": "https://example.com/api/endpoint",
    "cron": "0 32 17 * * ? *",
    "pause": false,
    "stateful": false
}`;
    } else if (type === 'weekly') {
        textarea.value = `{
    "label": "call Component every Friday at 13:20",
    "component": "com.example.WeeklyJobComponent",
    "cron": "0 20 13 ? * FRI *",
    "pause": false,
    "stateful": false
}`;
    } else if (type === 'monthly') {
        textarea.value = `{
    "label": "call URL once a month on the 14th when a weekday",
    "url": "/monthly-report.cfm",
    "cron": "0 0 9 14 * MON-FRI *",
    "pause": false,
    "stateful": false
}`;
    } else if (type === 'once') {
        textarea.value = `{
    "label": "call URL once on specific date",
    "url": "/one-time-task.cfm",
    "cron": "0 0 12 25 12 ? 2025",
    "pause": false,
    "stateful": false
}`;
    }
    
    // Focus the textarea so user can see the change
    textarea.focus();
}
			
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
	<cfset exceptionKey="expection"&(req.plugin?:"")>
	<cfif structKeyExists(session,exceptionKey)>
		<div class="error">
			<b>#session[exceptionKey].message#</b><br>
			<cfif len(session[exceptionKey].detail?:"")>#markdownToHTML(session[exceptionKey].detail?:"")#</cfif>
		
			<cfset structDelete(session,exceptionKey)>
		</div>
	</cfif>
	<cfif isNull(quartz)>
		<cfif state EQ "running">
			<div class="error">Quartz cannot be loaded for unknown reasons, check the logs for details.</div>
		<cfelseif state EQ "stopped">
			<div class="error">Quartz Scheduler is not running.</div>
			
			<cfoutput>
			<form  action="#action('update')#" method="post">
			<table class="maintbl checkboxtbl">
				<tfoot>
				<tr>
					<td>
						<cfif state EQ "running">
							<input class="bl submit" type="submit" name="stop" value="#lang.btnStop#" />   
							<input class="br submit" type="submit" name="restart" value="#lang.btnRestart#" />   
						<cfelseif state EQ "stopped">
							<input class="b submit" type="submit" name="start" value="#lang.btnStart#" />   
						</cfif>
					</td>
				</tr>
				</tfoot>
				</table>
			</form>
				</cfoutput>
		</cfif>
		
	<cfelse>
		<cfoutput><h2>Jobs</h2></cfoutput>
		

	<form  action="#action('update')#" method="post">
		<cfif jobs.recordcount>
			<table class="maintbl checkboxtbl">
			<thead>
				<tr>
					<th><input type="checkbox" class="checkbox" name="all" onclick="selectAll(this)" /></th>
					<th>Job / Endpoint</th>
					<th>Schedule</th>
					<th >Last / Next Execution</th>
					<!---<th>Next Execution</th>
					<th>Final Execution</th>
					<th>Start Time</th>
					<th>End Time</th> --->
					<th ></th>
				</tr>
			</thead>
			<tbody>
				<cfoutput query="jobs">
				<tr class="<cfif jobs.state EQ 'NORMAL'>OK<cfelseif jobs.state EQ 'PAUSED'>tblContentYellow<cfelseif jobs.state EQ 'ERROR' OR jobs.state EQ 'BLOCKED'>notOK<cfelse>complete</cfif>">
					<td rowspan="2"><input type="checkbox" class="checkbox" name="row[]" value="#jobs.jobName#:#jobs.jobGroup#"></td>
					<td rowspan="2"><b>#jobs.jobLabel#</b><cfif len(jobs.slug?:"") and jobs.jobLabel NEQ jobs.slug> (#jobs.slug#)</cfif><br>#jobs.endpoint#</td>
					<td rowspan="2">
						<cfif jobs.scheduleType EQ "interval">
							#displayTimeRange(jobs.schedule)#
						<cfelse>
							#jobs.schedule#
						</cfif>
					</td>
					<td ><cfif isDate(jobs.previousFireTime)>#diffFormat(jobs.previousFireTime)#<cfelse>-</cfif></td>

					<td rowspan="2">
						<a class="btn-mini sprite edit" title="Edit" href="#action('overview',"jobName=#jobs.jobName#&jobGroup=#jobs.jobGroup#")#"><span>Edit</span></a>
					</td>
				</tr>
				<tr class="<cfif jobs.state EQ 'NORMAL'>OK<cfelseif jobs.state EQ 'PAUSED'>tblContentYellow<cfelseif jobs.state EQ 'ERROR' OR jobs.state EQ 'BLOCKED'>notOK<cfelse>complete</cfif>">
					<td ><cfif jobs.state!="PAUSED" && isDate(jobs.nextFireTime)>#diffFormat(jobs.nextFireTime)#<cfelse>-</cfif></td>
				</tr>
				</cfoutput>
			</tbody>
			<tfoot>
				<tr>
				<td colspan="3">
					<input class="bl submit" type="submit" name="pause" value="#lang.btnPause#" />
					<input class="bm submit" type="submit" name="resume" value="#lang.btnResume#" />
					<input class="br submit" type="submit" name="delete" value="#lang.btnDelete#" />
				</td>
				<td colspan="2" align="right">
					<table class="maintbl">
						<tbody>
							<tr>
								<td class="OK">&nbsp;&nbsp;Active&nbsp;&nbsp;</td>
								<td class="tblContentYellow">&nbsp;&nbsp;Paused&nbsp;&nbsp;</td>
								<td class="notOK">&nbsp;&nbsp;Error&nbsp;&nbsp;</td>
							</tr>
						</tbody>
					</table>
				</td>
				</tr>
			</tfoot>
		</table>
		<input class="b submit" type="button" name="refresh" value="#lang.btnRefresh#" style="width:100%" onclick="window.location.reload();" />
	<cfelse>
		<p>#lang.noJobs#</p>
	</cfif>
	<cfoutput>
		<h2>#jobs.recordcount?lang.addUpdateTitle:lang.addTitle#</h2>
		<p>#jobs.recordcount?lang.addUpdateDesc:lang.addDesc#</p>
	</cfoutput>
	<table class="maintbl checkboxtbl">
		<tr>
			<tr>
				<td>
					<textarea class="schedule-textarea" id="jobConfigTextarea" name="newval"><cfif structKeyExists(variables, "editval")>#variables.editval#</cfif></textarea>
					<input class="b submit" type="submit" name="add" value="#jobs.recordcount?lang.btnAddUpdate:lang.btnAdd#" />   
					<cfif not structKeyExists(variables, "editval")>
						<div class="comment" style="margin: 10px 0 5px 0;">
							<strong>#lang.quickTitle#:</strong> #lang.quickDesc#:
							<ul>
						        <li><a href="javascript:void(0)" class="btn-mini" onclick="insertTemplate('url')">#lang.quickURLEvery5s#</a></li>
						        <li><a href="javascript:void(0)" class="btn-mini" onclick="insertTemplate('component')">#lang.quickCFCEveryHour#</a></li>
						        <li><a href="javascript:void(0)" class="btn-mini" onclick="insertTemplate('daily')">#lang.quickDaily#</a></li>
						        <li><a href="javascript:void(0)" class="btn-mini" onclick="insertTemplate('weekly')">#lang.quickWeekly#</a></li>
						        <li><a href="javascript:void(0)" class="btn-mini" onclick="insertTemplate('monthly')">#lang.quickMonthly#</a></li>
						        <li><a href="javascript:void(0)" class="btn-mini" onclick="insertTemplate('once')">#lang.quickOnce#</a></li>
						    </ul>
						</div>
					</cfif>
					
					<div class="comment">
						<strong>Notes:</strong>  
						<ul>
							<li>Use online "cron expression generators" to create schedule patterns like "0/5 * 9-17 ? * MON-FRI".</li>
							<li>URLs starting with "/" make local calls (same server). Full URLs (e.g., "http://...") allow external/distributed execution.</li>
							<li>Provide a single JSON object for one job, or an array of objects for multiple jobs.</li>
							<li>If you wanna use the same component/url for multiple jobs, define the key "slug" as identifier like "lucee-org-once-a-day".</li>
						</ul>
						
						<br><br>
						
						
						<br><br>
						<strong>Tips:</strong> 
						
						
					</div> </td>
		</tr>
	</table>
	</form>
		<!--- <cfif !isNull(session.alwaysNew)><cfdump var="#jobs#" expand=false></cfif>--->
	</cfif>





<cfif (hasClassicTasks?:false)>

		

	

	<cfoutput>
		<br><br><h3>#lang.importTitle#</h3>
		<form  action="#action('import')#" method="post">
		<p>#lang.importDesc#</p>
	</cfoutput>
	<table class="maintbl checkboxtbl">
		<tr>
			<tr>
				<td colspan="9">
					<div class="comment">
						<input  class="radio" type="radio" name="importAnd" value="" checked="true">&nbsp;&nbsp;#lang.importAndNothing#<br>
						<input  class="radio" type="radio" name="importAnd" value="pause">&nbsp;&nbsp;#lang.importAndPause#<br>
						<input  class="radio" type="radio" name="importAnd" value="delete">&nbsp;&nbsp;#lang.importAndDelete#
					</div>
					<input class="b submit" type="submit" name="import" value="#lang.importButton#" />   
				</td>
		</tr>
	</table>
	</form>
</cfif>





</cfoutput>
