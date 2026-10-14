/**
 * Holds the worker thread for a number of milliseconds from the job data key "millis".
 * Tests use it to call triggerJob() again while a stateful job is still running.
 */
component {

    public static void function reset() {
        static.runs = 0;
        static.started = false;
    }

    public static boolean function hasStarted() {
        return static.started ?: false;
    }

    public static numeric function runCount() {
        return static.runs ?: 0;
    }

    public function init() {
        variables.millis = val(arguments.millis ?: 0);
        return this;
    }

    public void function execute() {
        static.started = true;
        static.runs = (static.runs ?: 0) + 1;
        if (variables.millis > 0) sleep(variables.millis);
    }
}
