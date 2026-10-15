component {

    static {
        static.DEFAULT_CONFIG='{
    /* Scheduler concurrency (all optional):
       "threadPoolCount": 10,                     // worker threads per node (org.quartz.threadPool.threadCount)
       "threadPoolPriority": 5,                   // worker thread priority
       "batchTriggerAcquisitionMaxCount": 10,     // due triggers acquired+fired per cycle; defaults to threadPoolCount.
                                                  //   Quartz defaults this to 1, which serializes dispatch per node.
       "batchTriggerAcquisitionFireAheadTimeWindow": 0,
       "misfirePolicy": "doNothing",              // global default; per-job "misfirePolicy" overrides it.
                                                  //   cron: smart|doNothing|fireAndProceed|ignoreMisfires (default doNothing)
                                                  //   interval: smart|doNothing|fireNow|ignoreMisfires (default smart)
    */
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
        variables.id=arguments.id?:"";
        variables.config=arguments.config?:{};
        variables.configFile=resolveConfigFile(variables.config);
        
        ensureConfigFile(variables.configFile);
	}

    /**
     * resolves the config file from the environment or the gateway config.
     * used by init() and as fallback when this instance did not run init() (LDEV-6460)
     */
    public static string function resolveConfigFile(struct config={}) {
        var path=server.system.environment.QUARTZ_CONFIGFILE?:"";
        if(isEmpty(path)) {
            path=arguments.config.custom.configFile?:"{lucee-server}/quartz/config.json";
            path=Quartz::resolvePath(path);
        }
        return path;
    }

    /**
     * creates the config file when it does not exist yet (default config or tasks migrated from cfschedule).
     * Quartz.cfc expands the path again, that only works when the file exists (LDEV-6460)
     */
    private static void function ensureConfigFile(required string configFile) {
        if(!fileExists(arguments.configFile)) {
            // make sure parent directory exists
            var dir=getDirectoryFromPath(arguments.configFile);
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
            fileWrite(arguments.configFile, config);
            // pause the existing tasks, so they not run twice
            org.lucee.extension.quartz.ClassicMigrator::pauseTasks();
        }
    }

    private string function getConfigFile() {
        if(isNull(variables.configFile) || isEmpty(variables.configFile)) {
            variables.configFile=resolveConfigFile(variables.config?:{});
            ensureConfigFile(variables.configFile);
        }
        return variables.configFile;
    }

	public void function start() {
        variables.instance=new Quartz(getConfigFile());
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

	public function loadConfig() {
        if(!isNull(variables.instance)) return variables.instance.loadConfig();
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
            return Quartz::sendMessageStatic(getConfigFile(),data);
        }
        
    
    
    }
}