/**
 * The MCP tools of the Quartz extension. Thin wrappers over the Quartz component.
 */
component {

    static {
        static.DEFAULT_GROUP = "cfm";
    }

    /**
     * @quartzProvider function returning the running Quartz instance
     */
    public any function init(required any quartzProvider) {
        variables.quartzProvider = arguments.quartzProvider;
        return this;
    }

    public void function register(required ToolRegistry registry) {
        var self = this;
        var nameProps = {
            "name": { "type": "string", "description": "Name (id) of the job, as returned by quartz_listJobs" },
            "slug": { "type": "string", "description": "Slug of the job, alternative to name" },
            "group": { "type": "string", "description": "Group of the job, default [#static.DEFAULT_GROUP#]" }
        };

        // ---- read ----
        registry.register("quartz_listJobs", "read",
            "List all jobs of the scheduler (name, group, label, slug, url or component).",
            function(args) { return self.listJobs(); });

        registry.register("quartz_listTriggers", "read",
            "List the triggers of the scheduler with schedule, state and previous/next fire time. Optionally filtered.",
            function(args) { return self.listTriggers(args); },
            { "properties": {
                "name": { "type": "string", "description": "only the trigger of this job name" },
                "group": { "type": "string", "description": "only triggers of this job group" },
                "state": { "type": "string", "description": "only triggers in this state, e.g. NORMAL, PAUSED, BLOCKED, ERROR" }
            } });

        registry.register("quartz_getJob", "read",
            "Get the complete definition (as it would be written to the config) and the trigger of one job.",
            function(args) { return self.getJob(args); },
            { "properties": nameProps });

        registry.register("quartz_getMetadata", "read",
            "Get scheduler metadata: state, version, thread pool, job store, running since, jobs executed.",
            function(args) { return self.getMetadata(); });

        registry.register("quartz_listRunning", "read",
            "List the jobs currently executing on this node.",
            function(args) { return self.listRunning(); });

        // ---- write ----
        registry.register("quartz_appendJob", "write",
            "Add a job, or update it when a job with the same slug, url or component exists. The job needs a [url] or [component] and a [cron] or [interval] (seconds). Optional: label, slug, startAt, endAt, pause, stateful, misfirePolicy, timeout.",
            function(args) { return self.appendJob(args); },
            { "properties": { "job": {
                "type": "object",
                "description": "The job definition, same format as an entry of [jobs] in the scheduler config",
                "properties": {
                    "label": { "type": "string" },
                    "slug": { "type": "string" },
                    "url": { "type": "string", "description": "url or path to call" },
                    "component": { "type": "string", "description": "path of the component to execute" },
                    "cron": { "type": "string", "description": "quartz cron expression" },
                    "interval": { "type": "number", "description": "interval in seconds" },
                    "startAt": { "type": "string" },
                    "endAt": { "type": "string" },
                    "pause": { "type": "boolean" },
                    "misfirePolicy": { "type": "string" }
                }
            } }, "required": [ "job" ] });

        registry.register("quartz_deleteJob", "write", "Delete a job.",
            function(args) { return self.deleteJob(args); },
            { "properties": nameProps });

        registry.register("quartz_pauseJob", "write", "Pause a job.",
            function(args) { return self.jobAction("pauseJob", args, "paused"); },
            { "properties": nameProps });

        registry.register("quartz_unpauseJob", "write", "Unpause a paused job.",
            function(args) { return self.jobAction("resumeJob", args, "unpaused"); },
            { "properties": nameProps });

        registry.register("quartz_pauseAll", "write", "Pause all jobs.",
            function(args) { quartz().pauseAllJobs(); return { "success": true, "message": "all jobs paused" }; });

        registry.register("quartz_unpauseAll", "write", "Unpause all jobs.",
            function(args) { quartz().resumeAllJobs(); return { "success": true, "message": "all jobs unpaused" }; });

        registry.register("quartz_executeJob", "write", "Execute a job right now, independent of its schedule.",
            function(args) { return self.jobAction("triggerJob", args, "triggered"); },
            { "properties": nameProps });
    }

    // ---------------------------------------------------------------- read

    public array function listJobs() {
        return queryToArray(quartz().getJobsAsQuery(false));
    }

    public array function listTriggers(required struct args) {
        var all = queryToArray(quartz().getTriggersAsQuery(false));
        var result = [];
        loop array=all item="local.trigger" {
            if (len(args.name ?: "") && trigger.jobName != args.name) continue;
            if (len(args.group ?: "") && trigger.jobGroup != args.group) continue;
            if (len(args.state ?: "") && uCase(trigger.state) != uCase(args.state)) continue;
            arrayAppend(result, trigger);
        }
        return result;
    }

    public struct function getJob(required struct args) {
        var q = quartz();
        var key = requireJob(q, args);
        var definition = q.exportJob(key.name, key.group);
        if (isNull(definition)) throw "job [#key.name#] has no trigger";
        var trigger = {};
        loop array=queryToArray(q.getTriggersAsQuery(false)) item="local.t" {
            if (t.jobName == key.name && t.jobGroup == key.group) {
                trigger = t;
                break;
            }
        }
        return normalize({ "name": key.name, "group": key.group, "job": definition, "trigger": trigger });
    }

    public struct function getMetadata() {
        var q = quartz();
        var meta = normalize(q.getMetadataAsStruct());
        meta["state"] = q.getState();
        var config = q.getConfig();
        var settings = [:];
        loop array=["threadPoolCount", "threadPoolPriority", "batchTriggerAcquisitionMaxCount", "batchTriggerAcquisitionFireAheadTimeWindow", "misfirePolicy", "primary"] item="local.k" {
            if (structKeyExists(config, k)) settings[k] = config[k];
        }
        // the store definition holds credentials, only the type is shown
        if (structKeyExists(config, "store") && isStruct(config.store) && structKeyExists(config.store, "type")) settings["storeType"] = config.store.type;
        meta["config"] = settings;
        return meta;
    }

    public array function listRunning() {
        return normalize(quartz().getRunningJobs());
    }

    // ---------------------------------------------------------------- write

    public struct function appendJob(required struct args) {
        var job = args.job ?: nullValue();
        if (isNull(job) || !isStruct(job)) throw "argument [job] is required and must be an object";
        if (!len(job.url ?: "") && !len(job.component ?: "") && !len(job.cfc ?: "")) throw "invalid job, [url] or [component] is required";
        if (!len(job.cron ?: "") && !len(job.interval ?: "")) throw "invalid job, [cron] or [interval] is required";
        var q = quartz();
        q.addJob(job);
        return normalize({ "success": true, "name": job.id, "group": static.DEFAULT_GROUP, "message": "job added" });
    }

    public struct function deleteJob(required struct args) {
        var q = quartz();
        var key = requireJob(q, args);
        q.deleteJob(key.name, key.group);
        return { "success": true, "name": key.name, "group": key.group, "message": "job deleted" };
    }

    public struct function jobAction(required string action, required struct args, required string message) {
        var q = quartz();
        var key = requireJob(q, args);
        q[arguments.action](key.name, key.group);
        return { "success": true, "name": key.name, "group": key.group, "message": "job " & arguments.message };
    }

    // ---------------------------------------------------------------- helpers

    private any function quartz() {
        return variables.quartzProvider();
    }

    /** resolves name/slug and group of the arguments and makes sure the job exists */
    private struct function requireJob(required any q, required struct args) {
        var name = trim(args.name ?: "");
        if (!len(name) && len(args.slug ?: "")) name = hash(args.slug, "quick");
        if (!len(name)) throw "argument [name] or [slug] is required";
        var group = len(args.group ?: "") ? args.group : static.DEFAULT_GROUP;
        loop array=q.getJobs() item="local.job" {
            if (job.getKey().getName() == name && job.getKey().getGroup() == group) return { "name": name, "group": group };
        }
        throw "job [#name#] in group [#group#] not found";
    }

    private array function queryToArray(required query qry) {
        var rows = [];
        loop from=1 to=qry.recordCount index="local.i" {
            arrayAppend(rows, normalize(queryGetRow(qry, i)));
        }
        return rows;
    }

    /** makes a value safe for JSON: dates as ISO 8601 UTC, java objects as string */
    private any function normalize(required any value) {
        if (isNull(arguments.value)) return "";
        if (isInstanceOf(arguments.value, "java.util.Date")) {
            return dateTimeFormat(dateConvert("local2utc", arguments.value), "yyyy-MM-dd'T'HH:mm:ss'Z'");
        }
        if (isSimpleValue(arguments.value)) return arguments.value;
        if (isStruct(arguments.value)) {
            var result = [:];
            loop struct=arguments.value index="local.k" item="local.v" {
                result[k] = isNull(v) ? "" : normalize(v);
            }
            return result;
        }
        if (isArray(arguments.value)) {
            var result = [];
            loop array=arguments.value item="local.v" {
                arrayAppend(result, isNull(v) ? "" : normalize(v));
            }
            return result;
        }
        return toString(arguments.value);
    }
}
