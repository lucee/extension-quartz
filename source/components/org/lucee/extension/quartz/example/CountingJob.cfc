/**
 * Test job. Counts each execute() in the file named by job data "runFile", then throws
 * when job data "fail" is true. The count is written before the throw so a failed manual
 * run is still observable.
 */
component {

    public void function init() {
        variables.runFile = arguments.runFile ?: "";
        variables.fail = arguments.fail ?: false;
    }

    public void function execute() {
        if (!len(variables.runFile ?: "")) throw "runFile is required";
        var n = fileExists(variables.runFile) ? val(fileRead(variables.runFile)) : 0;
        fileWrite(variables.runFile, n + 1);
        if (isTrue(variables.fail)) {
            throw(type="Test.ManualRunFailed", message="manual run failed on purpose");
        }
    }

    private boolean function isTrue(required any value) {
        return isBoolean(arguments.value) && arguments.value;
    }
}
