/**
 * Simple Example
 */
component {
    
    public function init() {
        systemOutput("--- arguments passed into simple job example ---",1,1);
        systemOutput(arguments,1,1);
    }

    public void function execute() {
        systemOutput("--- execute simple job example ---",1,1)
    }
}