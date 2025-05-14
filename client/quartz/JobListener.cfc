component implementsJava="org.quartz.JobListener" {
    public String function getName() { 
        return "CustomJobListener";
    }

    public void function jobToBeExecuted( context) {
    }

    public void function jobExecutionVetoed( context) {
    }

    public void function jobWasExecuted( context,  jobException) {
        if (!isNull(jobException)) {
        }
    }
    public void function onMissingMethod( ) {
    }
}