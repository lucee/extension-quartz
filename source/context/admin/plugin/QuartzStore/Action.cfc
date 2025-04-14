component extends="org.lucee.extension.quartz.QuartzPlugin" {
	
	static {
		static.NL="
";
	}
	variables.gatewayName="quartz-task";

	variables.storages={
"datasource": '{
	"type": "datasource"
	// available datasources: #arrayToList(getDatasourceNames(),", ")#
	,"datasource": ""
	,"tablePrefix": "QRTZ_"
	// ,"cluster": true
	// ,"clusterCheckinInterval": 15000
	// ,"username": "${JDBC_USERNAME}"
	// ,"password": "${JDBC_PASSWORD}"
}'
,"redis": '{
	"type": "redis"
	,"host": "localhost"
	// ,"port": 6379
	// ,"misfireThreshold": 60000
	// ,"password": "${REDIS_USERNAME}"
	// ,"redisCluster": true
	// ,"redisSentinel": true
	// ,"masterGroupName": ""
	// ,"database": 0
	// ,"lockTimeout": 30000
	// ,"ssl": true

}'
	}


	
	  
	
	/**
	 * this function will be called to initialize
	 */
	public function init(struct lang, struct app) {
		//app.note=load();
	}

	public function overview(struct lang, struct app, struct req) {
		try {
			variables.state=GatewayState(variables.gatewayName);
		

			variables.storage=sendGatewayMessage(variables.gatewayName, {
				"action":"store"
				,"type":"raw"
			});
			variables.storageLoaded=deserializeJSON(variables.storage);
			variables.hasStorage=structCount(storageLoaded)>0;
		}
		catch(cfcatch) {
			handleException(lang, app, req, cfcatch);
		}
	}

	public function update(struct lang, struct app, struct req) {
		try {
			// delete
			if(structKeyExists(form, "delete")) {
				variables.storage=sendGatewayMessage(variables.gatewayName, {
					"action":"updatestore"
				});
			}
			// create
			if(structKeyExists(form, "create")) {
				// validate
				try {
					var data=deserializeJSON(form.newval);
				}
				catch(ex) {
					cfthrow (
							message : "failed to parse the given json string with the following exception:"
							,detail : "```#static.NL##ex.message##static.NL#```"
							cause:ex
						);
				}
				var updateData=form.newval;
			}
			// update
			if(structKeyExists(form, "update")) {
				// validate
				try {
					var data=deserializeJSON(form.editval);
				}
				catch(ex) {
					cfthrow (
							message : "failed to parse the given json string with the following exception:"
							,detail : "```#static.NL##ex.message##static.NL#```"
							cause:ex
						);
				}
				var updateData=form.editval;
			}

			if(!isNull(updateData)) {
				// validate datasource
				if("datasource"==data.type) {
					if(!structKeyExists(data, "datasource")) {
						cfthrow (message : "missing the key [datasource] in the given json structure.");
					}
					else if(isEmpty(trim(data.datasource))) {
						cfthrow (message : "the key [datasource] is empty.");
					}
					else if(!hasDatasource(trim(data.datasource))) {
						cfthrow (message : "there is no datasource with name [#trim(data.datasource)#], available datsources are [#arrayToList(getDatasourceNames(),", ")#].");
					}

				}
				else if("redis"==data.type) {
					if(!structKeyExists(data, "host")) {
						cfthrow (message : "missing the key [host] in the given json structure.");
					}
				}

				// store
				variables.storage=sendGatewayMessage(variables.gatewayName, {
					"action":"updatestore"
					,"store":updateData
				});
			}
			GatewayAction(variables.gatewayName,"stop",true);
			GatewayAction(variables.gatewayName,"start",true);
		}
		catch(cfcatch) {
			cfcatch.dataType=data.type?:"";
			handleException(lang, app, req, cfcatch);
		}
		return "redirect:overview";
	}
}