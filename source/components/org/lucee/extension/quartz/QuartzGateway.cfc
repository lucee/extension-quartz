component {
	
    // we do this cfc, because Lucee does not unload a component when updating the extension

	public void function init(string id, struct config, component listener) { 
        var path=config.custom.configFile?:"{lucee-server}/quartz/config.json";
        
        
        
        variables.configFile=expandPath(path);
        if(!fileExists(variables.configFile)) {
            fileWrite(variables.configFile, '{
    "jobs": [
        /*{
            "label": "Example for every 60 seconds",
            "url": "/jobs/dummy.cfm",
            "interval": 60,
            "startAt": "2021-04-22",
            "endAt": "2028-04-22",
            "pause": true
        },
        {
            "label": "Every 5 seconds, every minute, every hour between 09am and 17pm, of every work day",
            "url": "/jobs/dummy.cfm?id=2",
            "cron": "0/5 * 9-17 ? * MON-FRI",
            "pause": true
        },
        {
            "label": "Every 5 seconds, every minute, every hour between 09am and 17pm, of every work day",
            "url": "/jobs/dummy.cfm?id=2",
            "cron": "0/5 * 9-17 ? * MON-FRI",
            "pause": true
        },
        {
            "label": "every 2 seconds",
            "component": "org.lucee.extension.quartz.example.SimpleJobExample",
            "cron": "0/2 * * * * ?",
            "pause": false
        }*/
    ]
    ,"listener": [
        /*{
            "component": "org.lucee.extension.quartz.ConsoleListener",
            "stream": "err"
        }*/
    ]
    /*,"store": {
        "type": "jdbc",
        "datasource": "test",
        "tablePrefix": "QRTZ_",
        "driver": "com.mysql.cj.jdbc.Driver",
        "url": "jdbc:mysql://localhost:3307/test?characterEncoding=UTF-8&serverTimezone=GMT&maxReconnects=3",
        "username": "${JDBC_USERNAME}",
        "password": "${JDBC_PASSWORD}",
        "maxConnections": 5
    }*/
    /*,"store": {
        "type": "redis",
        "host": "localhost",
        "port": 6379,
        "misfireThreshold": 60000
    }*/
}');
        }
        variables.id=arguments.id?:"";
        variables.config=arguments.config?:{};
	}

	public void function start() {
        variables.instance=new Quartz(variables.configFile);
        variables.instance.start();
	}

	public void function stop() {
        if(!isNull(variables.instance)) variables.instance.stop();
        variables.instance=nullValue();
	}

	public void function restart() {
        stop();
        start();
	}

	public string function getState() {
		if(isNull(variables.instance)) return "stopped";
		return variables.instance.getState();
	}

	public string function setState(state) {
	}

	public string function sendMessage(struct data) {
        if(!isNull(variables.instance)) 
        	return variables.instance.sendMessageInstance(data);
        else {
            return Quartz::sendMessageStatic(variables.configFile,data);
        }
        
    
    
    }
}