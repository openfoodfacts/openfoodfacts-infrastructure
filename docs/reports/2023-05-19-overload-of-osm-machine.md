# 2023-05-18 Mongodb down

## Symptom

* Symptom: Reported by users who could not edit. No databases responding, meaning that mongodb might be slow or down.
* @teolemon calls @alexgarel and they start debugging.
* off3 could be pinged it from off1, with 0,2 ms ping times, and 2 to 5 ms ping times from time to time, potentially hinting at CPU overload according to @alexgarel. ssh is not responding at this point.
* @teolemon calls @cq94 and @stephanegigandet to go further.
## Investigation
* @stephanegigandet noticed the SSH and the general command slowness mentionned above
* @cq94 noticed that the ZFS pool write time were abnormally high on the underlying physical machine.
* @cq94 restarted the virtual machine. 
* @stephanegigandet restarted manually mongodb which had not been automatically restarted.
* It was mentionned that the newly available ressources granted by @cq94 were not visible by the virtual machine
* It was mentionned that it was not the first time that the var/?? designed to restart mongodb was wiped away on restart.
* @cq94 later mentionned that it might have been related to the use of reset vs restart parameter
* The root password has been changed by @stephanegigandet to give @cq94 access to the virtual machine.

## Resolution

* Christian Quest (@cq94) has found the culprit (A VM related to Open Street Map taking all ressources) after shutting down other VMs on the same physical machine one by one. He reduced the resources for said VM (preventing the reocccurence of such an incident), and contacting its owner. 
* Our VM was not at fault.

## Conclusion

## Mitigation steps taken
* Christian is migrating the OS of our VM to SSD (it was on hard drive, unlike mongodb) since it was the physical harddrives that had been saturated by the other container. 
* The situation is unlikely to happen on the middle/long term since we have a plan to move the MongoDB database back to our own servers.
