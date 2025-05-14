/**
 * Purpose of this interface is to provide the Javasettings needed for Quartz to all component that need them
 */
interface susi=2  javaSettings='{
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
}