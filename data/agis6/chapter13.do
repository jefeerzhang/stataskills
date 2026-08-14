* Chaper 13 missing.do
clear
use chapter13_missing 
misstable summarize ln_wagem gradem agem ttl_expm tenurem not_smsa south blackm
misstable patterns ln_wagem gradem agem ttl_expm tenurem not_smsa south blackm
quietly misstable summarize ln_wagem gradem agem ttl_expm tenurem not_smsa south blackm, gen(miss_)
describe miss_*
logit miss_ln_wagem gradem agem ttl_expm tenurem not_smsa south blackm if ln_wagem <= .
logit miss_gradem ln_wagem agem ttl_expm tenurem not_smsa south blackm if gradem <= .
logit miss_agem ln_wagem gradem ttl_expm tenurem not_smsa south blackm if agem <= .
logit miss_ttl_expm ln_wagem gradem agem tenurem not_smsa south blackm if ttl_expm <= .
logit miss_tenurem ln_wagem gradem agem ttl_expm not_smsa south blackm if tenurem <= .
logit miss_blackm ln_wagem gradem agem ttl_expm tenurem not_smsa south if blackm <= .

* Arbitrary missing-data pattern

* If we were concerned about distributions we could transform variables 
* prior to the imputation and then reverse this latter
* With a very big dataset, mlong only has complete case observations 
* in the 0 imputation. This can save space if that is a problem.
mi set flong
mi register imputed ln_wagem gradem agem ttl_expm tenurem blackm
mi register regular not_smsa south 
mi impute mvn ln_wagem gradem agem ttl_expm tenurem blackm, add(20) rseed(2121)
mi estimate, dftable: regress ln_wagem gradem agem ttl_expm tenurem not_smsa south blackm
mibeta ln_wagem gradem agem ttl_expm tenurem not_smsa south blackm, fisherz miopts(vartable)
summarize ln_wagem gradem agem ttl_expm tenurem not_smsa south blackm if _mi_m > 0
