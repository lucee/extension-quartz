component {

    import "lucee.extension.gateway.MailWatcher"


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
                }
            ]
        };
        static.bundleName="org.quartz-scheduler.quartz";
        static.DateBuilder=createObject("java","org.quartz.DateBuilder",static.javaSettings);
        static.SimpleScheduleBuilder=createObject("java","org.quartz.SimpleScheduleBuilder",static.javaSettings);
        static.JobBuilder=createObject("java","org.quartz.JobBuilder",static.javaSettings);
        static.TriggerBuilder=createObject("java","org.quartz.TriggerBuilder",static.javaSettings);
        static.StdSchedulerFactory=createObject("java","org.quartz.impl.StdSchedulerFactory",static.javaSettings);
        static.CronScheduleBuilder = createObject("java", "org.quartz.CronScheduleBuilder",static.javaSettings);
        static.CronTrigger = createObject("java", "org.quartz.CronTrigger",static.javaSettings);
        static.NoOpJob = createObject("java", "org.quartz.jobs.NoOpJob",static.javaSettings);
    }


    public void function init(configFile) {
        variables.configFile=expandPath(arguments.configFile);
        variables.config=deserializeJSON(fileRead(variables.configFile));
    }

    public void function run() {
        try {
            var factory = static.StdSchedulerFactory.init();
            var scheduler = factory.getScheduler();

            // listener
            var jobListener = JavaCast("org.quartz.JobListener",new JobListener(),static.javaSettings);
            scheduler.getListenerManager().addJobListener(jobListener);
            
            // Load CFMJob and convert to a quartz Job class
            var clazz=JavaCast("org.quartz.Job",new CFMJob(),static.javaSettings).getClass(); 
            
            
            // define all the jobs and triggers based on the given config
            loop array=config.jobs item="local.jobData" {
                if(jobData.pause?:false) continue;
                
                // define job
                var job = static.JobBuilder.newJob(clazz)
                    .withIdentity(jobData.label, "cfm")
                    .usingJobData("path", jobData.url)
                    .build();

                // define trigger
                var builder=static.TriggerBuilder.newTrigger().withIdentity("trigger:"&jobData.label, "cfm");

                // when to start?
                if(!isNull(jobData.startAt)) {
                    builder.startAt(parseDateTime(jobData.startAt));
                }
                else builder.startNow();

                // when to end
                if(!isNull(jobData.endAt)) {
                    builder.endAt(parseDateTime(jobData.endAt));
                }

                // shedule (cron or interval)
                if(!isNull(jobData.interval)) {
                    builder.withSchedule(
                        static.SimpleScheduleBuilder.simpleSchedule()
                        .withIntervalInSeconds(jobData.interval)
                        .repeatForever()
                    );
                }
                else if(!isNull(jobData.cron)) {
                    builder.withSchedule(CronScheduleBuilder.cronSchedule(jobData.cron));
                }
                else throw "invalid job defintion, missing `cron` or `interval`";
                




                scheduler.scheduleJob(job, builder.build());
            }

            

            scheduler.start();
            dump(scheduler);flush;
            // wait
            sleep(10000);
        }
        finally {
            // shut down the scheduler
            dump("------- Shutting Down ---------------------");flush;
            scheduler.shutdown(true);
            dump("------- Shutdown Complete -----------------");flush;
        }
      }
}