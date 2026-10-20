/**
 * Purpose of this interface is to provide the Javasettings needed for Quartz to all component that need them
 */
interface susi=2  javaSettings='{
            "maven":[
                {
                    "groupId" : "org.quartz-scheduler",
                    "artifactId" : "quartz",
                    "version" : "2.3.2"
                },
                {
                    "groupId" : "org.slf4j",
                    "artifactId" : "slf4j-nop",
                    "version" : "1.7.36"
                },
                {
                    "groupId" : "org.lucee",
                    "artifactId" : "quartz-redis-jobstore",
                    "version" : "2.0.0.1-RC"
                }
            ]
        }' {
}