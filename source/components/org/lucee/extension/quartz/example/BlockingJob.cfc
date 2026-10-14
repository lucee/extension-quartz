/**
 * Holds the worker thread for a number of milliseconds from the job data key "millis".
 * Tests use it to call triggerJob() again while a stateful job is still running.
 *
 * A marker file (job data key "markerFile") is written before the sleep. The count in
 * that file is how many times execute() has been entered. The Quartz worker loads this
 * component on its own, so a static flag set here is not visible to the test thread.
 */
component {

    public function init() {
        variables.millis = val(arguments.millis ?: 0);
        variables.markerFile = arguments.markerFile ?: "";
        return this;
    }

    public void function execute() {
        if (len(variables.markerFile)) {
            var n = 0;
            if (fileExists(variables.markerFile)) n = val(trim(fileRead(variables.markerFile)));
            fileWrite(variables.markerFile, n + 1);
        }
        if (variables.millis > 0) sleep(variables.millis);
    }
}
