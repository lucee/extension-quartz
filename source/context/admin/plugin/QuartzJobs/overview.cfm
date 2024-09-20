<cfoutput>
<style>
.schedule-textarea {
    width: 100%; /* Make textarea full width */
    height: 100px; /* Set a fixed height for consistency */
    resize: vertical; /* Allow vertical resizing */
    box-sizing: border-box; /* Include padding/border in element's width and height */
    margin-bottom: 10px; /* Space between textarea and button */
}
</style>
	<cfscript>
	</cfscript>
		<meta charset="UTF-8">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
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
		
	<cfif isNull(quartz)>
		<cfif state EQ "running">
			<p class="important">Quartz cannot be loaded for unknown reasons, check the logs for details.</p>
		<cfelseif state EQ "stopped">
			<p class="important">Quartz Scheduler is not running.</p>
			
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
		<cfoutput><h1>Jobs</h1></cfoutput>


		<form  action="#action('update')#" method="post">
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
					<td rowspan="2"><b>#jobs.jobLabel#</b><br>#jobs.endpoint#</td>
					<td rowspan="2">#jobs.schedule# #jobs.scheduleType=="interval"?" seconds":""#</td>
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
				<td colspan="2">
					<input class="bl submit" type="submit" name="pause" value="#lang.btnPause#" />
					<input class="bm submit" type="submit" name="resume" value="#lang.btnResume#" />
					<input class="br submit" type="submit" name="delete" value="#lang.btnDelete#" />
				</td>
				<td colspan="3" align="right">
					<table>
						<tr>
							<td style="background-color:##e0f3e6;">&nbsp;&nbsp;Active&nbsp;&nbsp;</td>
							<td style="background-color:##fff9da;">&nbsp;&nbsp;Paused&nbsp;&nbsp;</td>
							<td style="background-color:##f9e0e0;">&nbsp;&nbsp;Error&nbsp;&nbsp;</td>
						</tr>
					</table>
				</td>
				</tr>
			</tfoot>
		</table>


	<cfoutput><h1>Create or Edit Job</h1></cfoutput>
	<table class="maintbl checkboxtbl">
		<tr>
			<tr>
				<td colspan="9">
					<textarea class="schedule-textarea" id="jobConfigTextarea" name="newval"><cfif structKeyExists(variables, "editval")>#variables.editval#<cfelse>{
	"label": "every 5 seconds on work hours",
	"url": "/example.cfm",
	"cron": "0/5 * 9-17 ? * MON-FRI",
	"pause": false
}</cfif></textarea>
					<input class="b submit" type="submit" name="add" value="#lang.btnAddUpdate#" />   
					<div class="comment">
						Note: You can use online tools to generate cron expressions. Just search for "cron expression generator" on Google. 
						<br><br>
						If the URL starts with "/", it will make a local call using the internalRequest function, meaning the job will run on the same server. 
						If the URL is a full address like "http://localhost:8888/jobs/dummy.cfm", the job can run from any server, which is useful for distributed or external tasks.
						<br><br>
						<strong>Tip:</strong> You can add a single job by providing a JSON structure with the job details. To add multiple jobs at once, use an array of such structures, with each structure representing a different job. This allows you to efficiently set up multiple tasks in one go.
					</div> </td>
		</tr>
	</table>
	</form>
		<!--- <cfif !isNull(session.alwaysNew)><cfdump var="#jobs#" expand=false></cfif>--->
	</cfif>
</cfoutput>
