/**
 * Simply calls an URL
 */
component extends="lucee.admin.plugin.Plugin" {

	variables.gatewayName="quartz-task";

	public function init(struct lang, struct app) {
		installGatewayIfNeeded();
	}


    public function handleException(struct lang, struct app, struct req, struct cfcatch) {
        // TODO get log from Quartz
        log log="application" type="error" exception=cfcatch;
        session["expection"&(req.plugin?:"")]=cfcatch;
    }

    public function getDatasourceNames() {
		var config=getPageContext().getConfig();
		var sources=config.getDataSources();
		var arr=[];
		loop array=sources item="local.src" {
			arrayAppend(arr, src.getName());
		}
		return arr;
	}
    public function getDatasourceNames() {
		var config=getPageContext().getConfig();
		var sources=config.getDataSources();
		var arr=[];
		loop array=sources item="local.src" {
			arrayAppend(arr, src.getName());
		}
		return arr;
	}

	public function hasDatasource(required string name) {
		var config=getPageContext().getConfig();
		var sources=config.getDataSources();
		loop array=sources item="local.src" {
			if(arguments.name==src.getName()) return true;
		}
		return false;
	}	

	public function hasGateway() localmode=true cachedWithin=createTimespan(0,0,0,1) {
		admin
			action="getGatewayEntries"
			type="#request.adminType#"
			password="#session["password"&request.adminType]#"
			returnVariable="entries";
		loop query=entries {
			if(variables.gatewayName==entries.id) return true;
		}
		return false;
	}

	public function installGatewayIfNeeded() localmode=true cachedWithin=createTimespan(0,0,0,1) {
		if(hasGateway()) return;
		
		admin 
			action="updateGatewayEntry"
			type="#request.adminType#"
			password="#session["password"&request.adminType]#"
			
			id=variables.gatewayName 
			class="" 
			cfcPath="org.lucee.extension.quartz.QuartzGateway"
			listenerCfcPath="" 
			startupMode="automatic"
			readOnly=false
			custom={
				'configFile':'{lucee-config}/quartz/config.json'
				,'logName':'scheduler'
			};
			GatewayAction(variables.gatewayName,"start",true);
	}

	
}