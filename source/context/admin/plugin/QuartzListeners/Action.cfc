component extends="lucee.admin.plugin.Plugin" {
	
	variables.gatewayName="quartz-task";
	
	/**
	 * this function will be called to initialize
	 */
	public function init(struct lang, struct app) {
		//app.note=load();
		
	}

	public function overview(struct lang, struct app, struct req) {
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

	public function update(struct lang, struct app, struct req) {
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
			// TODO error handling
			try {
				var quartz=getQuartz(variables.gatewayName);
				var cfc=trim(form.newcfc);
				var args=deserializeJSON(form.newargs);
				args["component"]=cfc;
				quartz.addListener(args);
			}
			catch(e) {
				systemOutput(e,1,1);
				rethrow;
			}
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