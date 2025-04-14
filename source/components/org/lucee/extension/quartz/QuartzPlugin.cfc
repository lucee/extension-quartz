/**
 * Simply calls an URL
 */
component extends="lucee.admin.plugin.Plugin" {
    public function handleException(struct lang, struct app, struct req, struct cfcatch) {
        // TODO get log from Quartz
        log log="application" type="error" exception=cfcatch;
        session["expection"&(req.plugin?:"")]=cfcatch;
    }

    public function getDatasourceNames() {
		var config=getPageContext().getConfig();
		var sources=config.getDataSources();
		var arr=[];
		loop array=sources item="local.src" {
			arrayAppend(arr, src.getName());
		}
		return arr;
	}
    public function getDatasourceNames() {
		var config=getPageContext().getConfig();
		var sources=config.getDataSources();
		var arr=[];
		loop array=sources item="local.src" {
			arrayAppend(arr, src.getName());
		}
		return arr;
	}

	public function hasDatasource(required string name) {
		var config=getPageContext().getConfig();
		var sources=config.getDataSources();
		loop array=sources item="local.src" {
			if(arguments.name==src.getName()) return true;
		}
		return false;
	}
}