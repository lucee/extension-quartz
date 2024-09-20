component extends="Gateway" {


    fields = array(
        field( "Config File", "configFile", "{lucee-config}/quartz/config.json", true, "Path to the Quarz config file containing the Quartz schdeuler configuration", "text" ) 
        ,field( "Log", "logName", "scheduler", true, "Where should the Quartz log?", "text" ) 
    );
    
    public function getLabel() {            return "Quartz Scheduler"; }

    public function getDescription() {      return "Quartz Scheduler is a powerful and flexible open-source job scheduling library for Java applications. It allows developers to schedule jobs to run at specified times or intervals, supporting both simple and complex scheduling scenarios, including cron-like expressions. Quartz Scheduler is suitable for use in both standalone applications and large-scale enterprise environments, offering features like clustering and persistence for high availability and scalability." }

    public function getCfcPath() { 
        pagePoolClear(); // this is a patch for a bug in Lucee, because Lucee follows the regular template cacheg rules for gateways, what is "once" by default.
        return "org.lucee.extension.quartz.QuartzGateway"; 
    }


    public function getClass() {            return ""; }

    public function getListenerPath() {     return ""; }


    // public function getListenerCfcMode() {  return "required"; }


    /*/ validate args and throw on failure
    public function onBeforeUpdate( required cfcPath, required startupMode, required custom ) {

        
    }   //*/

}