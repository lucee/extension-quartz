component extends="lucee.admin.plugin.Plugin" {
	
	variables.gatewayName="quartz-task";

	variables.storages={
"Redis": '{
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
,"JDBC": '{
	"type": "jdbc"
	,"datasource": ""
	,"tablePrefix": "QRTZ_"
	,"driver": ""
	,"url": ""
	// ,"cluster": true
	// ,"clusterCheckinInterval": 15000
	,"username": "${JDBC_USERNAME}"
	,"password": "${JDBC_PASSWORD}"
	// ,"maxConnections": 5
}'
	}


	
	  
	
	/**
	 * this function will be called to initialize
	 */
	public function init(struct lang, struct app) {
		//app.note=load();
	}

	public function overview(struct lang, struct app, struct req) {
		variables.state=GatewayState(variables.gatewayName);
		

		variables.storage=sendGatewayMessage(variables.gatewayName, {
            "action":"store"
			,"type":"raw"
        });
		variables.storageLoaded=deserializeJSON(variables.storage);
		variables.hasStorage=structCount(storageLoaded)>0;
	}

	public function update(struct lang, struct app, struct req) {
		// delete
		if(structKeyExists(form, "delete")) {
			variables.storage=sendGatewayMessage(variables.gatewayName, {
				"action":"updatestore"
			});
		}
		// create
		if(structKeyExists(form, "create")) {
			variables.storage=sendGatewayMessage(variables.gatewayName, {
				"action":"updatestore"
				,"store":form.newval
			});
		}
		// create
		if(structKeyExists(form, "update")) {
			variables.storage=sendGatewayMessage(variables.gatewayName, {
				"action":"updatestore"
				,"store":form.editval
			});
		}
		
		
		return "redirect:overview";
	}
}