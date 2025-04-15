component extends="org.lucee.extension.quartz.QuartzPlugin" {
	
	variables.gatewayName="quartz-task";

	static {
		static.NL="
";
		static.listenerFunctionNames=[
			"getName":""
			,"getDescription":""
			,"jobToBeExecuted":""
			,"jobExecutionVetoed":""
			,"jobWasExecuted":""
		];
	}
	
	/**
	 * this function will be called to initialize
	 */
	public function init(struct lang, struct app) {
		super.init(lang,app);
	}

	public function overview(struct lang, struct app, struct req) {
		try {
			variables.state=GatewayState(variables.gatewayName);
			if("running"==variables.state) {
				variables.quartz=getQuartz(variables.gatewayName);
				variables.listeners = variables.quartz.getListenersAsArray(true);
				if(structKeyExists(url, "editname")) {
					try {
						loop array=listeners item="local.listener" {
							if(url.editname==listener.name) {
								variables.editcfc=listener.component;
								variables.editargs=serializeJSON(var:listener.CONFIG,compact:false);
								break;
							}
						}
					}
					catch(e) {}
				}
			}
		}
		catch(cfcatch) {
			handleException(lang, app, req, cfcatch);
		}
	}

	public function update(struct lang, struct app, struct req) {
		try {
			if(structKeyExists(form, "row")) local.rows=form.row;
			else local.rows=[];
			
			// delete
			if(structKeyExists(form, "delete")) {
				loop array=rows item="local.name" {
					getQuartz(variables.gatewayName).deleteListener(name);
				}
			}
			// add
			else if(structKeyExists(form, "add")) {
				var quartz=getQuartz(variables.gatewayName);
				
				// read and test cfc
				var cfc=trim(form.newcfc);
				if(isEmpty(cfc)) throw "you need to define a component name like [org.lucee.extension.quartz.ConsoleListener] that implements the functions defined below.";
				var instance=createObject("component",cfc); // test loading the cfc
				var meta=getMetadata(instance);
				local.names=duplicate(static.listenerFunctionNames);

				// missing functions
				loop array=meta.functions item="local.f" {
					structDelete(names,f.name);
				}
				if(structCount(names)) {
					cfthrow (
						message : "Your component is missing the following functions [#structKeyList(names,", ")#]."
						,detail : "You can find detailed information about the functions below."
					);
				}
				
				// args
				form.newargs=trim(form.newargs);
				if(isEmpty(form.newargs)) {
					var args={};
				}
				else {
					try {
						var args=deserializeJSON(form.newargs);
					}
					catch(ex) {
						cfthrow (
							message : "failed to parse the given json string with the following exception:"
							,detail : "```#static.NL##ex.message##static.NL#```"
							,cause:ex
						);
					}
				}
				args["component"]=cfc;
				
				quartz.addListener(args);
			}
			// stop
			else if(structKeyExists(form, "stop")) {
				GatewayAction(variables.gatewayName,"stop",true);
			}
			// start
			else if(structKeyExists(form, "start")) {
				GatewayAction(variables.gatewayName,"start",true);
			}
			// restart
			else if(structKeyExists(form, "restart")) {
				GatewayAction(variables.gatewayName,"stop",true);
				GatewayAction(variables.gatewayName,"start",true);
			}
		}
		catch(cfcatch) {
			//rethrow;
			handleException(lang, app, req, cfcatch);
		}
		return "redirect:overview";
	}
	
	public function getQuartz(name="quartz-task") {
        var state=sendGatewayMessage(name, {
            "action":"state"
        });
        
        if(state!="running") {
            throw "Quartz Scheduler is no running, state is [#state#]";
        }
        var varName="quartzScheduler"&hash(createUniqueID(),"quick");

        // set it to the server scope
        sendGatewayMessage(name, {
            "action":"scheduler"
            ,"variable":"server."&varName
        });
        var quartz=server[varName];
        structDelete(server, varName,false);
        return quartz;
    }
}