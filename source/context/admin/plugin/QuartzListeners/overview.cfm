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
		
		#lang.purpose#<br>
		<b>#lang.listenerNotShared#</b>

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
		<cfoutput><h1>Listeners</h1></cfoutput>

		<form  action="#action('update')#" method="post">
		<cfif len(listeners)>
		<table class="maintbl checkboxtbl">
			<thead>
				<tr>
					<th><input type="checkbox" class="checkbox" name="all" onclick="selectAll(this)" /></th>
					<th>Component Path</th>
					<th style="width:0px"></th>
				</tr>
			</thead>
			<tbody>
				<cfoutput>
				<cfloop array="#listeners#" item="listener">
				<tr>
					<td><input type="checkbox" class="checkbox" name="row[]" value="#listener.name#"></td>
					<td><b>#listener.component#</b><cfif not isEmpty(listener.description?:"")><br></cfif>
					#listener.description?:""#</td>
					
					<td>
						<a class="btn-mini sprite edit" title="Edit below" href="#action('overview',"editname=#listener.name#")#"><span>Edit below</span></a>
					</td>
				</tr>
				</cfloop>
				</cfoutput>
			</tbody>
			<tfoot>
				<tr>
				<td colspan="3">
					<input class="b submit" type="submit" name="delete" value="#lang.btnDelete#" />
				</td>
				</tr>
			</tfoot>
		</table>
		<cfelse>
		<p>No listeners defined</p>
		</cfif>

	<cfoutput><h1>Create or Edit Listener</h1></cfoutput>
	<table class="maintbl checkboxtbl">
		<tbody>
			<tr>
				<th >Component</th>
				<td>
					<input name="newcfc" type="text" class="large" value="<cfif structKeyExists(variables, "editcfc")>#variables.editcfc#<cfelseif len(listeners) EQ 0>org.lucee.extension.quartz.ConsoleListener</cfif>">
					<div class="comment">
						#markdownToHTML(lang.descPath)#
					</div>
					</td>
			</tr>
			<tr>
				<th>Arguments</th>
				<td>
					<textarea class="schedule-textarea" id="jobConfigTextarea" name="newargs"><cfif structKeyExists(variables, "editargs")>#variables.editargs#<cfelseif len(listeners) EQ 0>{ "stream" : "err" }</cfif></textarea>
<div class="comment">
	#markdownToHTML(lang.descArg)#
</div></td>
			</tr>

		</tbody>
		<tfoot>
			<tr>
				<td colspan="2">
					<input class="b submit" type="submit" name="add" value="#lang.btnAddUpdate#" />
					<div class="comment">
						#markdownToHtml(lang.pattern)#
					</div>
				</td>
			</tr>
		</tfoot>
			
	</table>



	</form>

	
	</cfif>
	


</cfoutput>
