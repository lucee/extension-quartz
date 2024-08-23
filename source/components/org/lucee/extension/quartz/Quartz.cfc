component {
    // import java packages
    import org.quartz.*;
    import org.quartz.impl.*;
    import org.quartz.impl.matchers.*;
    import org.quartz.jobs.*;
    import java.util.*;


    static {
        static.javaSettings = {
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
                }
            ]
        };
        
        setJavaSettings(static.javaSettings);
        // Load URLJob and convert to a quartz Job class
        static.clazzURL=JavaCast("org.quartz.Job",new URLJob(),static.javaSettings).getClass(); 
       
        // Load ComponentJob and convert to a quartz Job class
        static.clazzCFC=JavaCast("org.quartz.Job",new ComponentJob(),static.javaSettings).getClass(); 
    }

    variables.state="stopped";

    public void function init(string configFile) { 

        // load config
        variables.configFile=expandPath(arguments.configFile);
        variables.config=deserializeJSON(fileRead(variables.configFile));
        
        variables.logName=variables.config.logName?:"scheduler"; // TODO check if the log exist



        log log=variables.logName type="debug" text="Quartz Scheduler: loaded config file [#variables.configFile#]";
    }

    public void function start() {
        setJavaSettings(static.javaSettings);
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
            
            // store
            if(!isNull(variables.config.store.type)) {
                // JDBC
                if("jdbc"==variables.config.store.type) {
                    var ds=variables.config.store.datasource;
                    // Configure JDBC job store
                    props.put("org.quartz.jobStore.class", "org.quartz.impl.jdbcjobstore.JobStoreTX");
                    props.put("org.quartz.jobStore.driverDelegateClass", "org.quartz.impl.jdbcjobstore.StdJDBCDelegate");
                    props.put("org.quartz.jobStore.dataSource", ds);
                    props.put("org.quartz.jobStore.tablePrefix", trim(variables.config.store.tablePrefix?:"QRTZ_"));
                    props.put("org.quartz.jobStore.isClustered", variables.config.store.cluster?:true);
                    props.put("org.quartz.jobStore.clusterCheckinInterval", trim(variables.config.store.clusterCheckinInterval?:"15000"));

                    // DataSource configuration
                    props.put("org.quartz.dataSource." & ds & ".driver",variables.config.store.driver);
                    props.put("org.quartz.dataSource." & ds & ".URL", variables.config.store.url);
                    props.put("org.quartz.dataSource." & ds & ".user", variables.config.store.username);
                    props.put("org.quartz.dataSource." & ds & ".password", variables.config.store.password);
                    props.put("org.quartz.dataSource." & ds & ".maxConnections", "5");
                }
            }

            variables.factory = new StdSchedulerFactory();
            variables.factory.initialize(props);
            //dump(variables.factory.getLog());
            variables.scheduler = variables.factory.getScheduler();

            // listener
            if(!isNull(config.listener)){
                var manager=variables.scheduler.getListenerManager();
                
                // load existing listeners
                var existingListener=[:];
                loop array=manager.getJobListeners() item="local.listener" {
                    existingListener[listener.name]=listener;
                }

                loop array=config.listener item="local.listenerData" {
                    try {
                        log log=variables.logName type="debug" text="Quartz Scheduler: loading job listener [#listenerData.component#]";
                        var cfc=createObject("component",listenerData.component);
                        // TODO only call init if exist
                        cfc.init(listenerData);
                        if(structKeyExists(existingListener, cfc.getName())) continue;
                        manager.addJobListener(JavaCast("org.quartz.JobListener",cfc,static.javaSettings));
                        log log=variables.logName type="debug" text="Quartz Scheduler: loaded job listener [#listenerData.component#]";
                    }
                    catch(ex) {
                        log log=variables.logName type="error" exception=ex;
                    }
                }
                var existingListener=[:];
                loop array=manager.getJobListeners() item="local.listener" {
                    existingListener[listener.name]=listener;
                }
            }
            

            // get all jobs already loaded via peristent storage
            var existingJobs=[:];
            var existingTriggers=[:];
            loop array=getTriggers() item="local.trigger" {
                dump(trigger.getJobKey().getName());
                existingJobs[trigger.getJobKey().getName()]={
                    "job":trigger.getJobKey(),
                    "trigger":trigger.getKey()
                };
                existingTriggers[trigger.getKey().getName()]={
                    "job":trigger.getJobKey(),
                    "trigger":trigger.getKey()
                };
            }
            
            // define all the jobs and triggers based on the given config
            loop array=config.jobs?:[] item="local.jobData" {
                //if(jobData.pause?:false) continue;
                
                try {
                    var job=createJob(jobData);
                    var trigger=createTrigger(jobData);
                    
                    // job exists?
                    if(structKeyExists(existingJobs, job.name)) {
                        // different trigger?
                        if(existingJobs[job.name].trigger.name!=trigger.name) {
                            variables.scheduler.rescheduleJob(existingJobs[job.name].trigger, trigger);
                        }
                        // change state of existing jobs
                        changeState(jobData.pause?:false, existingJobs[job.name].job,trigger.key);
                        
                        continue;
                    }
                    variables.scheduler.scheduleJob(job, trigger);

                    // change state of new jobs
                    if(jobData.pause?:false){
                        scheduler.pauseTrigger(trigger.getKey());
                        scheduler.pauseJob(job.getKey());
                    }
                    


                    log log=variables.logName type="debug" text="Quartz Scheduler: loaded job [#jobData.label#] with schedule [#jobData.cron?:("every "&jobData.interval&" second(s)")#]";
                }
                catch(ex) {
                    log log=variables.logName type="error" exception=ex;
                    continue;
                }
                
            }
            variables.scheduler.start();
            variables.state="running";
        }
        catch(e) {
            log log=variables.logName type="error" exception=e;
            variables.state="failed";
            rethrow;
        }
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
        setJavaSettings(static.javaSettings);
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
        setJavaSettings(static.javaSettings);
        
        if(isNull(variables.scheduler) || variables.scheduler.isShutdown() || variables.scheduler.isStarted()) {
            variables.state="stopped";
            return;
        }
        

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

	public void function restart() {
        stop();
        start();
	}
    

	package string function getScheduler() {
        return variables.scheduler;
	} 

    public function deleteJob(name,string group) {
        actionOnJob("deleteJob",name,group?:nullValue()) 
	} 

    public function resumeJob(name,string group) {
        actionOnJob("resumeJob",name,group?:nullValue()) 
	} 

	public function pauseJob(name,string group) {
        actionOnJob("pauseJob",name,group?:nullValue()) 
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
        sched[action](local.jk);
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

    

    public function getJobs() { 
        setJavaSettings(static.javaSettings);
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
        setJavaSettings(static.javaSettings);
        var triggers = [];
        if(!isNull(variables.scheduler)) {
            loop collection=variables.scheduler.getTriggerKeys(GroupMatcher::anyGroup()) index="local.i" item="local.key" {
                var trigger=variables.scheduler.getTrigger(key);
                if(!isNull(trigger)) arrayAppend(triggers, trigger);
            }
        }
        return triggers;
    }

}