### clusterctl unit test coverage and improvement areas
### https://cluster-api.sigs.k8s.io/clusterctl/overview.html

* clusterctl init
* clusterctl upgrade
* clusterctl delete
* clusterctl config cluster
* clusterctl move

* **Possible improvement areas: coverage < 50.0%, note that it might be acceptable to have 0% or < 50.0%**
* **After coverage result analysis (marked: 'OK-> <-'), it is visible that there are unit tests that don't call a certain function but instead manipulate data structures directly. This leads to 0% coverage results**
* **This is not the best practice. Future improvement area?**

```sh
Init:
sigs.k8s.io/cluster-api/cmd/clusterctl/client/init.go:32:				Init						60.0%
**OK->**
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/init.go:99:				InitImages					0.0%
**<-**
sigs.k8s.io/cluster-api/cmd/clusterctl/client/init.go:131:				setupInstaller					100.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/init.go:161:				addDefaultProviders				100.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/init.go:192:				addToInstaller					91.7%

Upgrade:
**OK-> covered in cmd/clusterctl/client/cluster/upgrader_test.go**
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/upgrade.go:34:				PlanUpgrade					0.0%
**<-**
sigs.k8s.io/cluster-api/cmd/clusterctl/client/upgrade.go:90:				ApplyUpgrade					71.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/upgrade.go:156:				addUpgradeItems					75.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/upgrade.go:170:				parseUpgradeItem				90.0%
**OK->**
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader.go:54:			UpgradeRef					0.0%
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader.go:75:			UpgradeRef					0.0%
**<-**
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader.go:59:			isPartialUpgrade				100.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader.go:88:			Plan						81.0%
**OK-> covered in cmd/clusterctl/client/upgrade_test.go**
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader.go:142:			ApplyPlan					0.0%
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader.go:162:			ApplyCustomPlan					0.0%
**<-**
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader.go:179:			getUpgradePlan					87.5%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader.go:206:			getManagementGroup				71.4%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader.go:222:			createCustomPlan				84.8%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader.go:297:			getProviderContractByVersion			70.0%
**OK->**
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader.go:317:			getUpgradeComponents				0.0%
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader.go:335:			doUpgrade					0.0%
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader.go:370:			newProviderUpgrader				0.0%
**<-**
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader_info.go:47:		getUpgradeInfo					82.9%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader_info.go:117:		newUpgradeInfo					100.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader_info.go:147:		getContractsForUpgrade				100.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader_info.go:162:		getLatestNextVersion				100.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/upgrader_info.go:189:		versionTag					100.0%

Delete:
sigs.k8s.io/cluster-api/cmd/clusterctl/client/delete.go:62:				Delete						80.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/delete.go:142:				appendProviders					100.0%

Config cluster:
sigs.k8s.io/cluster-api/cmd/clusterctl/client/config.go:28:				GetProvidersConfig				85.7%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/config.go:43:				GetProviderComponents				100.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/config.go:90:				numSources					100.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/config.go:138:				GetClusterTemplate				70.8%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/config.go:189:				getTemplateFromRepository			68.6%
**OK->**
sigs.k8s.io/cluster-api/cmd/clusterctl/client/config.go:256:				getTemplateFromConfigMap			37.5%
**<-**
sigs.k8s.io/cluster-api/cmd/clusterctl/client/config.go:275:				getTemplateFromURL				100.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/config.go:280:				templateOptionsToVariables			94.1%
**OK-> clusterctl v2?**
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/config/client.go:48:			Providers					0.0%
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/config/client.go:52:			Variables					0.0%
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/config/client.go:56:			ImageMeta					0.0%
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/config/client.go:64:			InjectReader					0.0%
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/config/client.go:71:			New						0.0%
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/config/client.go:75:			newConfigClient					0.0%
**<-**

Move:
**OK->**
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:51:			Move						0.0%
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:92:			newObjectMover					0.0%
**<-**
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:100:			checkProvisioningCompleted			88.5%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:159:			move						77.3%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:218:			addGroup					100.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:227:			hasNode						100.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:232:			getGroup					100.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:237:			getMoveSequence					100.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:284:			setClusterPause					78.6%
**OK->**
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:317:			ensureNamespaces				40.0%
**<-**
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:391:			createGroup					81.8%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:415:			createTargetObject				62.5%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:507:			deleteGroup					88.9%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:533:			deleteSourceObject				60.0%
sigs.k8s.io/cluster-api/cmd/clusterctl/client/cluster/mover.go:577:			checkTargetProviders				80.0%
**OK->**
*sigs.k8s.io/cluster-api/cmd/clusterctl/client/move.go:19:				Move						0.0%
**<-**
```
