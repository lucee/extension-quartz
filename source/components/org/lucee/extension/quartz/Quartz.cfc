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
        static.instanceName="Lucee Quartz Scheduler";

        // Load URLJob and convert to a quartz Job class
        static.clazzURL=JavaCast("org.quartz.Job",new URLJob()).getClass(); 
        static.clazzURLSF = JavaCast("org.quartz.StatefulJob", new StatefulURLJob()).getClass();
       
        // Load ComponentJob and convert to a quartz Job class
        static.clazzCFC=JavaCast("org.quartz.Job",new ComponentJob()).getClass(); 
        static.clazzCFCSF = JavaCast("org.quartz.StatefulJob", new StatefulComponentJob()).getClass();

        // Load ConnectionProvider
        static.connProvName=JavaCast("org.quartz.utils.ConnectionProvider",new ConnectionProviderImpl()).getClass().getName(); 
    }

    variables.state="stopped";

    public void function init(string configFile) { 
		_init(configFile, variables);
    }

	public static void function _init(string configFile, struct result) { 
        // load config
        result.configFile=expandPath(arguments.configFile);
        result.configUntranslated = deserializeJSON(fileRead(result.configFile));
        result.config = resolveEnvVar( result.configUntranslated);
        result.logName=result.config.logName?:"scheduler"; // TODO check if the log exist
        log log=result.logName type="debug" text="Quartz Scheduler: loaded config file [#result.configFile#]";
    }

    public void function start(boolean readJobs=false) {
        lock name="quartz-scheduler" {
            variables.state="starting";
            try {
                // Configure the scheduler properties programmatically
                var props = new Properties();
                props.put("org.quartz.scheduler.instanceName", static.instanceName);
                props.put("org.quartz.scheduler.instanceId", "AUTO");

                // Configure the thread pool
                props.put("org.quartz.threadPool.class", "org.quartz.simpl.SimpleThreadPool");
                props.put("org.quartz.threadPool.threadCount", trim(variables.config.threadPoolCount?:"10"));
                props.put("org.quartz.threadPool.threadPriority", trim(variables.config.threadPoolPriority?:"5"));
                props.put("org.quartz.threadPool.threadsInheritContextClassLoaderOfInitializingThread", "true");
                
                var hasStore=readJobs;
                // store
                if(!isNull(variables.config.store.type)) {
                    
                    // Datasource
                    if("datasource"==variables.config.store.type) {
                        var ds = variables.config.store.datasource;
                        
                        // Configure JDBC job store with Lucee datasource
                        props.put("org.quartz.jobStore.class", "org.quartz.impl.jdbcjobstore.JobStoreTX");
                        props.put("org.quartz.jobStore.driverDelegateClass", "org.quartz.impl.jdbcjobstore.StdJDBCDelegate");
                        props.put("org.quartz.jobStore.dataSource", asString(ds));
                        props.put("org.quartz.jobStore.tablePrefix", asString(trim(variables.config.store.tablePrefix?:"QRTZ_")));

                        // Critical clustering configurations
                        props.put("org.quartz.jobStore.isClustered", asString(variables.config.store.cluster?:true)); // Force clustering to be true
                        props.put("org.quartz.jobStore.clusterCheckinInterval", asString(trim(variables.config.store.clusterCheckinInterval?:"15000")));
                        props.put("org.quartz.jobStore.acquireTriggersWithinLock", "true"); // Important for clustered environments
                        props.put("org.quartz.jobStore.lockHandler.class", "org.quartz.impl.jdbcjobstore.UpdateLockRowSemaphore");
                        props.put("org.quartz.jobStore.misfireThreshold", asString(trim(variables.config.store.misfireThreshold?:"60000")));
                    
                        
                        // Use our ConnectionProvider implementation for Lucee datasources
                        props.put("org.quartz.dataSource." & ds & ".connectionProvider.class", static.connProvName);
                        props.put("org.quartz.dataSource." & ds & ".datasource", asString(ds));
                        props.put("org.quartz.dataSource." & ds & ".log", asString(variables.logName));
                        
                        // TODO Optional credentials if specified
                        //if(!isNull(variables.config.store.username)) props.put("org.quartz.dataSource." & ds & ".username", asString(variables.config.store.username));
                        //if(!isNull(variables.config.store.password)) props.put("org.quartz.dataSource." & ds & ".password", asString(variables.config.store.password));
                        hasStore = true;
                        log log=variables.logName type="info" text="Quartz Scheduler: configured with Lucee datasource [#ds#]";
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
                        log log=variables.logName type="info" text="Quartz Scheduler: configured with Redis Storage";
                    }
                }
                variables.factory = new StdSchedulerFactory(props);
                variables.scheduler = variables.factory.getScheduler();

                // load listeners
                if(!isNull(config.listeners)) {
                    var existingListener=getListeners(true);
                    loop array=config.listeners item="local.listenerData" {
                        try {
                            loadListener(listenerData,existingListener);
                        }
                        catch(ex) {
                            log log=variables.logName type="error" exception=ex;
                        }
                    }
                }
                
                // load jobs
                var isPrimaryFile = (config.primary ?: (hasStore ? "store" : "file")) == "file";
                if(!isNull(config.jobs)) {
                    var existingJobs=getExistingJobs();
                    
                    // we only load jobs from local, if there is no store or there are no jobs in store
                    if(!hasStore || isPrimaryFile || structCount(existingJobs)==0) {
                        
                        // handle deletions first if file is primary
                        if (isPrimaryFile && hasStore) {    
                            // create job ids from config
                            var configJobIds = {};
                            loop array=config.jobs item="local.jobData" {
                                if(structKeyExists(jobData, "slug")) {
                                    configJobIds[hash(jobData.slug, "quick")] = true;
                                }
                                else if(structKeyExists(jobData, "component")) {
                                    configJobIds[hash(jobData.component, "quick")] = true;
                                }
                                else if(structKeyExists(jobData, "url")) {
                                    configJobIds[hash(jobData.url, "quick")] = true;
                                }
                            }
                            loop collection=existingJobs item="local.key" {
                                if (!structKeyExists(configJobIds, key)) deleteJob(existingJobs[key].job);
                            }
                        }
                        // update or add jobs
                        loop array=config.jobs item="local.jobData" {
                            try {
                                loadJob(jobData,existingJobs);
                            }
                            catch(ex) {
                                log log=variables.logName type="error" exception=ex;
                            }
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

        thread cfc=this logName=variables.logName {
            while(true) {
                var state=cfc.getState();
                if("running"!=state && "starting"!=state) break;
                try {
                    var configFile=getPageContext().getConfig().getDeployDirectory().getReal("config.quartz");
                    if(fileExists(configFile)) {
                        // load the data
                        var newData=deserializeJSON(fileRead(configFile));
                         
                        // add jobs
                        loop array=newData.jobs?:[] item="job" {
                            cfc.addJob(job);
                        }

                        // add listeners
                        loop array=newData.listeners?:[] item="listener" {
                            cfc.addListener(listener);
                        }

                        // change store, this actually need a restart
                        if(!isNull(newData.store)) {
                            // TODO 
                            // var existingData=deserializeJSON(fileRead(cfc.getConfigFile()));
                            cfc.stop();
                            cfc.sendMessageStatic(cfc.getConfigFile(),{
                                "action":"updatestore"
                                ,"store":serializeJSON(newData.store)
                            });
                            if(fileExists(configFile)) fileDelete(configFile); // make sure the new startup does not pick up that file
                            cfc.init(cfc.getConfigFile());
                            cfc.start();
                        }
                        if(fileExists(configFile)) fileDelete(configFile);
                    }
                }
                catch(e) {
                    log log=logname type="error" exception=e;
                }
                sleep(10000);
            }
        }
	}

    public function addListener(listenerData) {
        var existingListener = getListeners(true);
        loadListener(listenerData, existingListener);

        var listeners=configUntranslated.listeners?:nullValue();
        if(isNull(listeners)) local.listeners=configUntranslated["listeners"]=[];
        
        // update
        var insert=true;
        loop array=listeners index="local.i" item="local.data" {
            if(data.component==listenerData.component) {
                listeners[i]=listenerData;
                insert=false;
                break;
            }
        }

        // insert
        if(insert) arrayAppend(listeners, listenerData);
        sync();
    }

    private function sync(boolean async=false) {
        var data=[:];
        data["jobs"]=exportJobs();
        data["listeners"]=variables.configUntranslated.listeners?:[];
        data["store"]=variables.configUntranslated.store?:{};
        if(structKeyExists(variables.configUntranslated,"primary") && !isEmpty(variables.configUntranslated.primary)) {
            data["primary"]=variables.configUntranslated.primary;
        }
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
            // slug match
            if(!isNull(jobData.slug) &&  jobData.slug==(data.slug?:"32749234z3")) {
                jobs[i]=jobData;
                insert=false;
                break;
            }
            // component match
            else if(!isNull(jobData.component) &&  jobData.component==(data.component?:"32749234z3")) {
                jobs[i]=jobData;
                insert=false;
                break;
            }
            // url match
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
        var jobName="";
        var ignores={};
        var isStateful = jobData.stateful ?: false;
        // URL Job
        if(!isNull(jobData.url)) {
            ignores["url"]="";
            jobName=jobData.url;
            if(structKeyExists(jobData, "slug")) {
                jobData.id=hash(jobData.slug,"quick");
            }
            else {
                jobData.id=hash(jobData.url,"quick");
            }
             // TODO make better
            ignores["id"]="";
            var builder = JobBuilder::newJob(isStateful?static.clazzURLSF:static.clazzURL)
                .withIdentity(jobData.id, "cfm")
                .usingJobData("url", jobData.url);
        }
        // Component Job
        else if(!isNull(jobData.component) || !isNull(jobData.cfc)){
            jobName=jobData.component?:jobData.cfc;
            ignores["component"]="";
            ignores["cfc"]="";
            if(structKeyExists(jobData, "slug")) {
                jobData.id=hash(jobData.slug,"quick");
            }
            else {
                jobData.id=hash(jobData.component?:jobData.cfc,"quick"); 
            }
            ignores["id"]="";
            var builder = JobBuilder::newJob(isStateful?static.clazzCFCSF:static.clazzCFC)
                .withIdentity(jobData.id, "cfm")
                .usingJobData("component", jobData.component?:jobData.cfc);
        }
        else {
            throw "invalid job defintion [#serializeJSON(jobData)#], missing `url` or `component`";
        }
        if(!isNull(jobData.cron)) {
            ignores["schedule"]="";
            ignores["cron"]="";
            builder
            .usingJobData("schedule", "cron")
            .usingJobData("cron", jobData.cron);
        }
        else if(!isNull(jobData.interval)) {
            ignores["schedule"]="";
            ignores["interval"]="";
            builder
            .usingJobData("schedule", "interval")
            .usingJobData("interval", jobData.interval);
        }

        ignores["log"]="";
        ignores["label"]="";
        builder
            .usingJobData("log", variables.logName)
            .usingJobData("label", jobData.label?:jobName);

        // we add all addional data we got to the job data
        loop struct=jobData index="local.k" item="local.v" {
            if(!isSimpleValue(v) || structKeyExists(ignores,k)) continue;
            builder.usingJobData(k, v);
        }
        return builder.build();                        
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
        sync();
	} 

	public function pauseJob(name,string group) {
        actionOnJob("pauseJob",name,group?:nullValue());
        sync();
	} 

    public function triggerJob(name,string group) {
        actionOnJob("triggerJob",name,group?:nullValue());
    }

    private function actionOnJob(string action,name,string group) {
        // name can be a JobJey object or a string
        if(isSimpleValue(name)) {
            local.jk=new JobKey(name,group);
            var strName=name;
        }
        else {
            local.jk=name;
            var strName=jk.getName();
        }
        var sched=variables.scheduler;
        if(isNull(sched)) throw "there is no scheduler initalized";
        var map = sched.getJobDetail(jk).getJobDataMap();
        sched[action](local.jk);

        log log=variables.logName type="debug" text="Quartz Scheduler: performing action [#action#] on job [#group#:#strName#]";

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
        var listeners=manager.getJobListener(name);
        if (!isNull(listeners)) {
            var cfc=listeners._toComponent();
            var path=getMetaData(cfc).fullname;
            manager.removeJobListener(name);
            
            var listeners=configUntranslated.listeners?:nullValue();
            if(!isNull(listeners)) {
                for(var i=len(listeners);i>0;i--) {
                    if(listeners[i].component==path) {
                        arrayDeleteAt(listeners, i);
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

    public function getConfigFile() {
        return variables.configFile;
	}

    /**
     * Gets the JobStore
     * @return The JobStore instance
     */
    public function getJobStore() {
        try {
            // Get the internal QuartzScheduler instance (sched field)
            var schedField = variables.scheduler.getClass().getDeclaredField("sched");
            schedField.setAccessible(true);
            var quartzScheduler = schedField.get(variables.scheduler);
            
            // Get the resources object
            var resourcesField = quartzScheduler.getClass().getDeclaredField("resources");
            resourcesField.setAccessible(true);
            var resources = resourcesField.get(quartzScheduler);
            
            return resources.getJobStore();
        }
        catch (any e) {
            log log=variables.logName type="error" text="Failed to get JobStore: #e.message#";
        }
        return nullValue();
    }

    public static function getInstance(string name="quartz-task") {
        var state=sendGatewayMessage(name, {
            "action":"state"
        });
        
        if(state!="running") {
            throw(
                type="Schedule.SchedulerNotRunning",
                message="Quartz Scheduler is not running",
                detail="Current state is [#state#]. The scheduler must be in 'running' state to perform operations. Please check the Lucee Administrator or event gateway configuration."
            );
        }
        
        var varName="quartzScheduler"&hash(createUniqueID(),"quick");

        // Temporarily set to server scope to retrieve the instance
        sendGatewayMessage(name, {
            "action":"scheduler",
            "variable":"server."&varName
        });
        
        var quartz=server[varName];
        structDelete(server, varName, false);
        
        return quartz;
    }
}