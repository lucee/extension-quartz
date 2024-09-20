component extends="QuartzSupport" javaSettings='{
            "maven":[
               {
                    "groupId" : "org.quartz-scheduler",
                    "artifactId" : "quartz-jobs",
                    "version" : "2.3.2"
                },
                {
                    "groupId" : "org.quartz-scheduler",
                    "artifactId" : "quartz",
                    "version" : "2.3.2"
                },
                {
                    "groupId" : "com.mchange",
                    "artifactId" : "c3p0",
                    "version" : "0.9.5.4"
                },
                {
                    "groupId" : "com.zaxxer",
                    "artifactId" : "HikariCP-java7",
                    "version" : "2.4.13"
                },
                {
                    "groupId" : "log4j",
                    "artifactId" : "log4j",
                    "version" : "1.2.17"
                },
                {
                    "groupId" : "org.slf4j",
                    "artifactId" : "slf4j-api",
                    "version" : "1.7.7"
                },
                {
                    "groupId" : "org.slf4j",
                    "artifactId" : "slf4j-log4j12",
                    "version" : "1.7.7"
                },
                {
                    "groupId" : "net.joelinn",
                    "artifactId" : "quartz-redis-jobstore",
                    "version" : "1.2.0"
                }
            ]
        }' {
    // import java packages
    import org.quartz.*;
    import org.quartz.impl.*;
    import org.quartz.impl.matchers.*;
    import org.quartz.jobs.*;
    import java.util.*;


    static {
        // Load URLJob and convert to a quartz Job class
        static.clazzURL=JavaCast("org.quartz.Job",new URLJob()).getClass(); 
       
        // Load ComponentJob and convert to a quartz Job class
        static.clazzCFC=JavaCast("org.quartz.Job",new ComponentJob()).getClass(); 
    }

    variables.state="stopped";

    public void function init(string configFile) { 
		_init(configFile, variables);
    }

	private static void function _init(string configFile, struct result) { 
        // load config
        result.configFile=expandPath(arguments.configFile);
        result.configUntranslated = deserializeJSON(fileRead(result.configFile));
        result.config = resolveEnvVar( result.configUntranslated);
        result.logName=result.config.logName?:"scheduler"; // TODO check if the log exist
        log log=result.logName type="debug" text="Quartz Scheduler: loaded config file [#result.configFile#]";
    }

    public void function start() {
        lock name="quartz-scheduler" {
            variables.state="starting";
            try {

                // Configure the scheduler properties programmatically
                var props = new Properties();
                // props.put("org.quartz.scheduler.instanceName", instanceName);
                // props.put("org.quartz.scheduler.instanceId", "AUTO");

                // Configure the thread pool
                props.put("org.quartz.threadPool.class", "org.quartz.simpl.SimpleThreadPool");
                props.put("org.quartz.threadPool.threadCount", trim(variables.config.threadPoolCount?:"10"));
                props.put("org.quartz.threadPool.threadPriority", trim(variables.config.threadPoolPriority?:"5"));

                props.put("org.quartz.threadPool.threadsInheritContextClassLoaderOfInitializingThread", "true");
                
                var hasStore=false;
                // store
                if(!isNull(variables.config.store.type)) {
                    
                    // JDBC
                    if("jdbc"==variables.config.store.type) {
                        var ds=variables.config.store.datasource;
                        // Configure JDBC job store
                        props.put("org.quartz.jobStore.class", "org.quartz.impl.jdbcjobstore.JobStoreTX");
                        props.put("org.quartz.jobStore.driverDelegateClass", "org.quartz.impl.jdbcjobstore.StdJDBCDelegate");
                        props.put("org.quartz.jobStore.dataSource", asString(ds));
                        props.put("org.quartz.jobStore.tablePrefix", asString(trim(variables.config.store.tablePrefix?:"QRTZ_")));
                        props.put("org.quartz.jobStore.isClustered", asString(variables.config.store.cluster?:true));
                        props.put("org.quartz.jobStore.clusterCheckinInterval", asString(trim(variables.config.store.clusterCheckinInterval?:"15000")));

                        // DataSource configuration
                        props.put("org.quartz.dataSource." & ds & ".driver",asString(variables.config.store.driver));
                        props.put("org.quartz.dataSource." & ds & ".URL", asString(variables.config.store.url));
                        props.put("org.quartz.dataSource." & ds & ".user", asString(variables.config.store.username));
                        props.put("org.quartz.dataSource." & ds & ".password", asString(variables.config.store.password));
                        props.put("org.quartz.dataSource." & ds & ".maxConnections", "5");
                        hasStore=true;
                    }
                    else if ("redis" == variables.config.store.type) {
                        // Configure Redis job store
                        props.put("org.quartz.jobStore.class", "net.joelinn.quartz.jobstore.RedisJobStore");
                        props.put("org.quartz.jobStore.keyPrefix",asString(variables.config.store.keyPrefix ?: "QRTZ_"));
                        props.put("org.quartz.jobStore.host", asString(variables.config.store.host ?: "localhost"));
                        props.put("org.quartz.jobStore.misfireThreshold", asString(variables.config.store.misfireThreshold ?: "60000"));
                        //props.put("org.quartz.jobStore.releaseTriggersInterval", asString(variables.config.store.releaseTriggersInterval ?: "600000"));
                        props.put("org.quartz.jobStore.port", asString(variables.config.store.port ?: "6379"));
                        if(!isNull(variables.config.store.password)) props.put("org.quartz.jobStore.password", asString(variables.config.store.password) );
                        props.put("org.quartz.jobStore.redisCluster",asString((variables.config.store.redisCluster?:false)==true));
                        props.put("org.quartz.jobStore.redisSentinel",asString((variables.config.store.redisSentinel?:false)==true));
                        props.put("org.quartz.jobStore.masterGroupName", asString(variables.config.store.masterGroupName ?: ""));
                        props.put("org.quartz.jobStore.database", asString(variables.config.store.database ?: 0));
                        props.put("org.quartz.jobStore.lockTimeout", asString(variables.config.store.lockTimeout ?: "30000"));
                        props.put("org.quartz.jobStore.ssl", asString((variables.config.store.ssl?:false)==true));
                        hasStore=true;
                    }
                }
                variables.factory = new StdSchedulerFactory(props);
                variables.scheduler = variables.factory.getScheduler();

                // load listeners
                if(!isNull(config.listener)) {
                    var existingListener=getListeners(true);
                    loop array=config.listener item="local.listenerData" {
                        try {
                            loadListener(listenerData,existingListener);
                        }
                        catch(ex) {
                            log log=variables.logName type="error" exception=ex;
                        }
                    }
                }
                
                // load jobs (we only load jobs from local, if there is no store, otherwise store is the master)
                if(!hasStore && !isNull(config.jobs)) {
                    var existingJobs=getExistingJobs();
                    loop array=config.jobs item="local.jobData" {
                        try {
                            loadJob(jobData,existingJobs);
                        }
                        catch(ex) {
                            log log=variables.logName type="error" exception=ex;
                        }
                    }
                }
                variables.scheduler.start();
                variables.state="running";
                sync(true);
            }
            catch(e) {
                log log=variables.logName type="error" exception=e;
                variables.state="failed";
                rethrow;
            }
        }
	}

    public function addListener(listenerData) {
        var existingListener = getListeners(true);
        loadListener(listenerData, existingListener);

        var listener=configUntranslated.listener?:nullValue();
        if(isNull(listener)) local.listener=configUntranslated["listener"]=[];
        
        // update
        var insert=true;
        loop array=listener index="local.i" item="local.data" {
            if(data.component==listenerData.component) {
                listener[i]=listenerData;
                insert=false;
                break;
            }
        }

        // insert
        if(insert) arrayAppend(listener, listenerData);
        sync();
    }

    private function sync(boolean async=false) {
        var data=[:];
        data["jobs"]=exportJobs();
        data["listener"]=variables.configUntranslated.listener?:[];
        data["store"]=variables.configUntranslated.store?:{};
        variables.configUntranslated=data;
        variables.config = resolveEnvVar(data);
        store(variables.configFile,variables.configUntranslated);
    }

    public static void function store(configFile,data) {
        fileWrite(configFile,serializeJSON(var:data,compact:false));
    }

    /**
     * loads a listener
     */
    public boolean function loadListener(listenerData,existingListener) {
        var manager=variables.scheduler.getListenerManager();
        log log=variables.logName type="debug" text="Quartz Scheduler: loading job listener [#listenerData.component#]";
        var cfc=createObject("component",listenerData.component);
        // TODO only call init if exist
        cfc.init(listenerData);
        if(structKeyExists(existingListener, cfc.getName())) return false;
        manager.addJobListener(JavaCast("org.quartz.JobListener",cfc));
        log log=variables.logName type="debug" text="Quartz Scheduler: loaded job listener [#listenerData.component#]";
        return true;
    }

    private struct function getExistingJobs() {
        var existingJobs=[:];
        var existingTriggers=[:];
        loop array=getTriggers() item="local.trigger" {
            // dump(trigger.getJobKey().getName());
            existingJobs[trigger.getJobKey().getName()]={
                "job":trigger.getJobKey(),
                "trigger":trigger.getKey()
            };
            existingTriggers[trigger.getKey().getName()]={
                "job":trigger.getJobKey(),
                "trigger":trigger.getKey()
            };
        }
        return existingJobs;
    }

    public function addJob(struct jobData) {
        var existingJobs = getExistingJobs();
        loadJob(jobData, existingJobs);

        var jobs=configUntranslated.jobs?:nullValue();
        if(isNull(jobs)) local.jobs=configUntranslated["jobs"]=[];
        
        // update
        var insert=true;
        loop array=jobs index="local.i" item="local.data" {
            if(!isNull(jobData.component) &&  jobData.component==(data.component?:"32749234z3")) {
                jobs[i]=jobData;
                insert=false;
                break;
            }
            else if(!isNull(jobData.url) &&  jobData.url==(data.url?:"32749234z3")) {
                jobs[i]=jobData;
                insert=false;
                break;
            }
        }

        // insert
        if(insert) arrayAppend(jobs, jobData);
        sync();
    }



    private function loadJob(struct data, existingJobs) {
        if(isNull(existingJobs)) existingJobs = getExistingJobs();
        
        var job=createJob(data);
        var trigger=createTrigger(data);
        
        // job exists?
        if(structKeyExists(existingJobs, job.name)) {
            // different trigger/job?
            var jobKey = existingJobs[job.name].job;
            var jobDetail = variables.scheduler.getJobDetail(jobKey);
            if(existingJobs[job.name].trigger.name!=trigger.name || !isJobDataMapEqual(jobDetail.getJobDataMap(),job.getJobDataMap())) {
                deleteJob(jobKey);
            }
            else {
                // change state of existing jobs
                changeState(data.pause?:false, existingJobs[job.name].job,trigger.key);
                //dump("------ update "&job.name&" ------");
                return;
            }
        }
        variables.scheduler.scheduleJob(job, trigger);
        // dump("------ add "&job.name&" ------");
        // change state of new jobs
        if(data.pause?:false) {
            //dump("--- pause ---");
            scheduler.pauseTrigger(trigger.getKey());
            scheduler.pauseJob(job.getKey());
        }
        log log=variables.logName type="debug" text="Quartz Scheduler: loaded job [#data.label#] with schedule [#data.cron?:("every "&data.interval&" second(s)")#]";
	} 

    
    
    private function changeState(pause, job,trigger) {
        var state=getScheduler().getTriggerState(trigger);
        if(pause) {
            if("PAUSED"!=state.name()) pauseJob(job);
        }
        else {
            if("PAUSED"==state.name()) resumeJob(job);
        }
    }


    private function createJob(jobData) {
        // URL Job
        if(!isNull(jobData.url)){
            jobData.id=hash(jobData.url,"quick"); // TODO make better
            var builder = JobBuilder::newJob(static.clazzURL)
                .withIdentity(jobData.id, "cfm")
                .usingJobData("url", jobData.url);
        }
        // Component Job
        else if(!isNull(jobData.component) || !isNull(jobData.cfc)){
            jobData.id=hash(jobData.component?:jobData.cfc,"quick"); // TODO make better
            var builder = JobBuilder::newJob(static.clazzCFC)
                .withIdentity(jobData.id, "cfm")
                .usingJobData("component", jobData.component?:jobData.cfc);
        }
        else {
            throw "invalid job defintion [#serializeJSON(jobData)#], missing `url` or `component`";
        }
        if(!isNull(jobData.cron)) {
            builder
            .usingJobData("schedule", "cron")
            .usingJobData("cron", jobData.cron);
        }
        else if(!isNull(jobData.interval)) {
            builder
            .usingJobData("schedule", "interval")
            .usingJobData("interval", jobData.interval);
        }
        return builder
            .usingJobData("log", variables.logName)
            .usingJobData("label", jobData.label)
                        .build();
                        
    }

    private function createTrigger(jobData) {

                    // define trigger
        var builder=TriggerBuilder::newTrigger();

                    // when to start?
                    if(!isNull(jobData.startAt)) {
                        builder.startAt(parseDateTime(jobData.startAt));
                    }
                    else builder.startNow();

                    // when to end
                    if(!isNull(jobData.endAt)) {
                        builder.endAt(parseDateTime(jobData.endAt));
                    }

        // shedule interval
                    if(!isNull(jobData.interval)) {
                        
                        builder
                        .withIdentity(hash(jobData.id&":"&jobData.interval,"quick"), "cfm")
                        .withSchedule(
                            SimpleScheduleBuilder::simpleSchedule()
                            .withIntervalInSeconds(jobData.interval)
                            .repeatForever()
                        );
                    }
        // shedule cron
                    else if(!isNull(jobData.cron)) {
                        builder
                        .withIdentity(hash(jobData.id&":"&jobData.cron,"quick"), "cfm")
                        .withSchedule(CronScheduleBuilder::cronSchedule(jobData.cron));
                    }
                    else {
            throw "invalid job defintion [#serializeJSON(jobData)#], missing `cron` or `interval`";
        }
        return builder.build();
    }

	public void function stop() {
        
        if(isNull(variables.scheduler) || variables.scheduler.isShutdown() || !variables.scheduler.isStarted()) {
            variables.state="stopped";
            return;
        }
       
        lock name="quartz-scheduler" {
            log log=variables.logName type="debug" text="Quartz Scheduler: stopping";
            try {
                variables.state="stopping";
                variables.scheduler.shutdown(true);
                variables.scheduler=nullValue();
                variables.state="stopped";
            }
            catch(e) {
                variables.state="error";
            }
            log log=variables.logName type="debug" text="Quartz Scheduler: stopped";
        }
	}

	public void function restart() {
        stop();
        start();
	}
    

	package string function getScheduler() {
        return variables.scheduler;
	} 

    public function deleteJob(name,string group) {
        var map=actionOnJob("deleteJob",name,group?:nullValue());
        
        /* becausse sync takes the jobs from quartz anyway, this does not matter
        var jobs=configUntranslated.jobs?:nullValue();
        if(!isNull(jobs)) {
            local.cfc=map["component"]?:nullValue();
            local.url=map["url"]?:nullValue();    
            for(var i=len(jobs);i>0;i--) {
                if(!isNull(cfc) && jobs[i].component==cfc) {
                    arrayDeleteAt(jobs, i);
                    break;
                }
                else if(!isNull(local.url) && jobs[i].url==local.url) {
                    arrayDeleteAt(jobs, i);
                    break;
                }
            }
        }*/
        sync();
	} 

    public function resumeJob(name,string group) {
        actionOnJob("resumeJob",name,group?:nullValue());
	} 

	public function pauseJob(name,string group) {
        actionOnJob("pauseJob",name,group?:nullValue());
	} 

    private function actionOnJob(string action,name,string group) {
        // name can be a JobJey object or a string
        if(isSimpleValue(name)) {
            local.jk=new JobKey(name,group);
        }
        else {
            local.jk=name;
        }
        var sched=variables.scheduler;
        if(isNull(sched)) throw "there is no scheduler initalized";
        var map = sched.getJobDetail(jk).getJobDataMap();
        sched[action](local.jk);
        return map;
	} 


	public string function pauseAllJobs() {
        var sched=variables.scheduler;
        if(isNull(sched)) throw "there is no scheduler initalized";
        sched.pauseAll();
	} 

    public string function resumeAllJobs() {
        var sched=variables.scheduler;
        if(isNull(sched)) throw "there is no scheduler initalized";
        sched.resumeAll();
	}

    public boolean function deleteListener(name) {
        if(isNull(variables.scheduler)) return false;
        var manager=variables.scheduler.getListenerManager();
        var listener=manager.getJobListener(name);
        if (!isNull(listener)) {
            var cfc=listener._toComponent();
            var path=getMetaData(cfc).fullname;
            manager.removeJobListener(name);
            
            var listener=configUntranslated.listener?:nullValue();
            if(!isNull(listener)) {
                for(var i=len(listener);i>0;i--) {
                    if(listener[i].component==path) {
                        arrayDeleteAt(listener, i);
                        break;
                    }
                }
            }
            sync();
            return true;
        }
        return false;
	}

	public string function getState() {
        return variables.state;
	}
	public static array function getStates() {
        if(isNull(static.states)) {
            local.names=[];
            loop array=TriggerState::values() item="local.enum" {
                arrayAppend(names, enum.name())
            }
            static.states=local.names;
        }
        return static.states;
	} 

    public function getListeners(boolean asStruct=false) {
        var listeners=asStruct?[:]:[];
        if(!isNull(variables.scheduler)) {
            var manager=variables.scheduler.getListenerManager();
            loop array=manager.getJobListeners() item="local.listener" {
                if(!isNull(listener)) {
                    if(asStruct)  listeners[listener.name]=listener;
                    else arrayAppend(listeners, listener);
                }
            }
        }
        return listeners;
	}

    public function getConfig() {
        return variables.config?:{};
	}

    public function getJobs() { 
        var jobs = [];
        if(!isNull(variables.scheduler)) {
            loop collection=variables.scheduler.getJobKeys(GroupMatcher::anyGroup()) index="local.i" item="local.key" {
                var job=variables.scheduler.getJobDetail(key);
                if(!isNull(job)) arrayAppend(jobs, job);
            }
        }
        return jobs;
	}

    public function getTriggers() {
        var triggers = [];
        if(!isNull(variables.scheduler)) {
            loop collection=variables.scheduler.getTriggerKeys(GroupMatcher::anyGroup()) index="local.i" item="local.key" {
                var trigger=variables.scheduler.getTrigger(key);
                if(!isNull(trigger)) arrayAppend(triggers, trigger);
            }
        }
        return triggers;
    }

    /**
     * Event Gateway interface
     */
    public string function sendMessageInstance(struct data) {
        var action=data.action?:"undefined";
        if("state"==action) return getState();
        if("scheduler"==action) {
            setVariable(data.variable, this);
            return true;
        }
        if("updatestore"==action) {
            stop();
            var res=Quartz::sendMessageStatic(variables.configFile, data,variables);
            start();
            systemOutput(res,1,1);
            return res;
		}


		return Quartz::sendMessageStatic(variables.configFile, data,variables);
    }

	public static string function sendMessageStatic(string configFile,struct data, struct internalData=nullValue()) {
        var action=data.action?:"list";
		
		// load data 
		if(isNull(internalData)) {
			arguments.internalData=[:];
			_init(configFile,internalData);
		}
		if("store"==action) {
			if("raw"==(data.type?:"raw")) return serializeJson(var:internalData.configUntranslated.store?:{},compact:false);
            return serializeJson(var:internalData.config.store?:{},compact:false);
		}
		if("updatestore"==action) {
            var strStore=data.store?:"{}";
			var store=deserializeJSON(strStore);
            if(!isStruct(store)) throw "store need to be a struct";
            internalData.configUntranslated["store"]=store;
            systemOutput(store,1,1);
            systemOutput(internalData,1,1);
            Quartz::store(configFile,internalData.configUntranslated);
            return strStore;
		}



		return "";
	}
    public function getMetadata() {
        if(!isNull(variables.scheduler)) {
            return variables.scheduler.getMetaData();
        }
	}    
}