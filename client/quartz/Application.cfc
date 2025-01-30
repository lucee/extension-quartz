component {
	
	this.javasettingsX = {
		"maven":[
			{
				"groupId" : "org.quartz-scheduler",
				"artifactId" : "quartz",
				"version" : "2.3.2"
			},
			{
				"groupId" : "org.quartz-scheduler",
				"artifactId" : "quartz-jobs",
				"version" : "2.3.2"
			}
		]
	}

	this.datasources["testm"] = {
		class: "com.mysql.cj.jdbc.Driver", 
		bundleName: "com.mysql.cj", 
		bundleVersion: "9.0.0",
		connectionString: "jdbc:mysql://localhost:3307/test?characterEncoding=UTF-8&serverTimezone=GMT&maxReconnects=3",
		username: "root",
		password: "redBat73",
		
		// optional settings
		blob:true, // default: false
		clob:true, // default: false
		connectionLimit:100, // default:-1
		liveTimeout:15, // default: -1; unit: minutes
		alwaysSetTimeout:true, // default: false
		validate:false, // default: false
	};



	this.monitoring.showDoc=true;
	this.monitoring.showDebug=true;
}