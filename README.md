# StoreToolsContrib
Foswiki Store: development tools

While developing VersatileStoreContrib for Foswiki I wrote these tools to perform Store conversions with benchmarking. Various other tools were developed to help with Store development.

Crucially each tool is written within a framework (inherits from base tool class). Therefore, the tool can be compact with the main tool handling the comamnd line in a consistent way.

The tool was developed with http://foswiki.org/Development/StoresShouldBePassedConfigHash in mind. This must be reviewed and approved by the community or these tools will need to be changed to copy the apt Foswiki::Cfg between calls to particular stores.

bulk_copy.pl has since been developed specifically to convert from old to new stores. There are pros and cons of the two approaches.
