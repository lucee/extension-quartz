component {

    static {
        static.DEFAULT_CONFIG='{
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
}';
    }

	
    // we do this cfc, because Lucee does not unload a component when updating the extension

	public void function init(string id, struct config, component listener) { 
        var path=server.system.environment.QUARTZ_CONFIGFILE?:"";
        if(isEmpty(path)) {
            path=config.custom.configFile?:"{lucee-server}/quartz/config.json";
            path=expandPath(path);
        }
        variables.configFile=path;
        
        if(!fileExists(variables.configFile)) {
            // make sure parent directory exists
            var dir=getDirectoryFromPath(variables.configFile);
            if(!directoryExists(dir)) {
                directoryCreate(dir,true,true);
            }

            // import tasks from cfschedule
            var jobs=ClassicMigrator::translateTasksToJobs();
            // if there are no jibs we simply create the default config
            if(len(jobs)==0) {
                var config=static.DEFAULT_CONFIG;
            }
            else {
                var config=serializeJSON({
                    "jobs": jobs,
                    "listener": [],
                    "store": {}
                });
            }
            fileWrite(variables.configFile, config);
            // pause the existing tasks, so they not run twice
            org.lucee.extension.quartz.ClassicMigrator::pauseTasks();
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