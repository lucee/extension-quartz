    <cfscript>
    function mySuccess() {
        return "Susi Sorglos";
    }
    
    mySuccess():function(result,error) {
        request.testFunctionListener=result;
    };
    // wait for the thread to finish
    sleep(100);
    dump(request.testFunctionListener ?: "undefined1");
    </cfscript>

<cfscript>

dump(hash(fileRead("/Users/mic/Test/test-cfconfig/lucee-server/context/recipes/basic-date.md"),"md5"));

abort;

// create inline component for CharSequence
cs=new component implementsJava="java.lang.CharSequence" {
variables.text="en_us";
        systemOutput("<print-stack-trace>",1,1);
    public function init() {
    }
    public function onMissingMethod(missingMethodName, missingMethodArguments) {
        if("toString"==missingMethodName) return variables.text;
        else throw "method #missingMethodName# not supported yet!";
    }
};

  
dump(cs.toString());
dump(cs);


// setLocale is expecting a String as argument PageContext.setLocale(java.lang.String)
obj=JavaCast("java.lang.CharSequence",cs);
dump(obj.toString());
dump(obj);
abort;
// use the CharSequence object
getPageContext().setLocale(obj);
     
    
    
    
    // create inline component for CharSequence
    cs=new component implementsJava="java.lang.CharSequence" {
       variables.text="Susi Sorglos";
    
        public function onMissingMethod(missingMethodName, missingMethodArguments) {
            if("toString"==missingMethodName) return variables.text;
            else throw "method #missingMethodName# not supported yet!";
        }
    };
    dump(cs);

    // explicit cast to CharSequence
    obj=JavaCast("java.lang.CharSequence",cs);
    dump(obj);

    // handle it like a string
    echo(obj);
    
    
    
    
    
    abort;
    
    
    quartz=new Quartz();
    //job=new HelloJob();

    job=new component implementsJava="org.quartz.Job" {
        public function init() {
            systemOutput("init - " & now(),1,1);
        }
    
        public void function execute(context) {
            systemOutput("execute - " & now(),1,1);
        }
    };
    dump(job);




    // explicit cast to "org.quartz.Job" 
    obj=JavaCast("org.quartz.Job",job);
    //obj.execute();
    
    
    
    clazz=getMetaData(obj);
    
    
    
    dump(clazz);


    //dump(jjob);
    //dump(getMetaData(jjob));
    abort;

    dump(server.lucee.version);

    //dump(job);
    quartz.run(job);

    //dump(quartz);
    //dump(job);

</cfscript>