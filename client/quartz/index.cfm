<cfscript>
/*
query name="q" datasource="testm" {
    ```
    select * from QRTZ_BLOB_TRIGGERS

    ```
}
dump(q);


query name="tables" datasource="testm" {
    ```
    show tables

    ```
}

loop query=tables {
    try {
        if(left(tables.Tables_in_test,5)=="QRTZ_") {
            query name="q" datasource="testm" {
                ```
                select * from <cfoutput>#tables.Tables_in_test#</cfoutput>
            
                ```
            }
            dump(q);
        }
    }
    catch(e) {echo(e)}
}



dump(q);
abort;*/

</cfscript>

<cfscript>
    

if(!isNull(url.stop)) {
    if(!isNull(application.quartz)) {
        dump("stopping");
        try {
            application.quartz.stop();
            application.quartz=nullValue();
        }
        catch(e) {
            application.quartz=nullValue();
            //echo(e);
        }
    }
}


//dump(getPageContext().getConfig());
//f=createObject("java","czzx72zohynhx.org.lucee.extension.quartz.URLJob");
//dump(f.getCanonicalPath());
// 603686925
// 6269431 478612000
dump("----- Quartz #now()# ----");
configFile=expandPath("{lucee-config}/quartz/config.json");
dump(configFile);
if(isNull(application.quartz)) {
    //dump(getComponentMetadata("org.lucee.extension.quartz.Quartz"));
    application.quartz=new org.lucee.extension.quartz.Quartz(configFile);
    dump("starting");
    application.quartz.restart();
    dump("started");
}
quartz=application.quartz;


 if(!isNull(url.delete)) {
    loop array=quartz.getJobs() item="job" {
        dump(quartz.deleteJob(job.name,job.group));
    }
    
   
    abort;
}


dump("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    
quartz.addJob({
    "label": "every 20 seconds",
    "component": "org.lucee.extension.quartz.example.SimpleJobExample",
    "cron": "0/20 * * * * ?",
    "pause": true
    });
    dump("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    jobs = quartz.getTriggersAsQuery( false);
dump(jobs);
abort;

// dump(application.quartz.getJobs());
//dump(application.quartz.getJobs());
/**/
qry=quartz.getTriggersAsQuery(quartz,true);
//dump(qry);
flush;
// pause all jobs
//quartz.pauseAll();
// pause a specific job via name/group
quartz.pauseJob(qry.jobName,qry.jobGroup);
// pause a specific job via jobkey
dump(qry);
quartz.pauseJob(qry.jobKey[2]);

qry=quartz.getTriggersAsQuery(quartz,false);
dump(qry);
flush;

// resume a specific job via name/group
quartz.resumeJob(qry.jobName,qry.jobGroup);
qry=quartz.getTriggersAsQuery(quartz,false);
dump(qry);
// resume all jobs
//quartz.resumeAllJobs();
qry=quartz.getTriggersAsQuery(quartz,false);
dump(qry);
flush;



loop times=1 {
    // triggers
    triggers=application.quartz.getTriggers();
    //dump(triggers);
    qry=quartz.getTriggersAsQuery(quartz,true);
    dump(qry);

    flush;
    //sleep(1000);
}



// jobs
jobs=application.quartz.getJobs();
//dump(jobs);
//qry=quartz.getTriggersAsQuery(quartz);
dump(quartz.getJobsAsQuery(quartz,true));

flush;


</cfscript>