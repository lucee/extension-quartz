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
		
	

	<form  action="#action('update')#" method="post">
	<cfoutput>
		<h1>Status (#state#)</h1>
		<cfif state EQ "running">
			Stop local representation of the Quartz Scheduler, that does not affect other server sharing the same job storage.
		<cfelseif state EQ "stopped">
			Start local representation of the Quartz Scheduler, that does not affect other server sharing the same job storage.
		</cfif>
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
	</cfoutput>
	</form>
<cfif not isNull(quartz)>
		<cfoutput><h1>Info</h1>
		<table class="maintbl checkboxtbl">
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
	</cfif>
	


</cfoutput>
