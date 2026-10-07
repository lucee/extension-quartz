/** Used by QuartzMcpTest: just enough of Quartz.cfc for the parts of the MCP server that only need the config */
component {

    public any function init(struct config = {}) {
        variables.config = arguments.config;
        return this;
    }

    public struct function getConfig() {
        return variables.config;
    }

    public array function getJobs() {
        return [];
    }
}
