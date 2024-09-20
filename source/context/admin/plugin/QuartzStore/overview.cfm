<cfoutput>
<style>
.schedule-textarea {
    width: 100%; /* Make textarea full width */
    height: 200px; /* Set a fixed height for consistency */
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
	<p>#lang.purpose#</p>

	<cfif hasStorage>	
		<h2>Modify your Storage</h2>
		<p>#lang.modifyYourStorage#</p>
	
		<form  action="#action('update')#" method="post">
			<table class="maintbl checkboxtbl">	
			<tr>
				<td colspan="1">
					<textarea class="schedule-textarea" name="editval">#storage#</textarea>
					<span class="comment">#lang.modifyYourStorageComment#</span>
				</td>
			</tr>
			<tfoot>
			<tr>
				<td colspan="1">
						<input class="b submit" type="submit" name="update" value="#lang.btnUpdate#" />  
						<input class="b submit" type="submit" name="delete" value="#lang.btnDelete#" />  	
					<div class="comment"></div>
				</td>
			</tr>
			</tfoot>	
			</table>
		</form>





	<cfelse>	
		<h2>Choose a Storage</h2>
		<p>#lang.createYourStorage#</p>
		<cfloop struct="#variables.storages#" index="k" item="v">
			<cfif hasStorage and k NEQ variables.storageLoaded.type><cfcontinue></cfif>
	
			<form  action="#action('update')#" method="post">
			<table class="maintbl checkboxtbl">	
			<tr>
				<th>
					<h3>#k#</h3>
					#lang["info"&k]#
				</th>
			</tr>
			<tr>
				<td colspan="1">
					<textarea class="schedule-textarea" name="newval">#hasStorage?storage:v#</textarea>
					<span class="comment">#lang.createYourStorageComment#</span>
				</td>
			</tr>
			<tfoot>
			<tr>
				<td colspan="1">
					<cfif hasStorage>
						<input class="b submit" type="submit" name="update" value="#replace(lang.btnUpdate,"{type}",k)#" />  
						<input class="b submit" type="submit" name="delete" value="#replace(lang.btnDelete,"{type}",k)#" />  	
					<cfelse>
						<input class="b submit" type="submit" name="create" value="#replace(lang.btnCreate,"{type}",k)#" />  
					</cfif> 
					<div class="comment"></div>
				</td>
			</tr>
			</tfoot>	
			</table>
		</form>
		</cfloop>


	</cfif>

		
		
		


	


</cfoutput>
