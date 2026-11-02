# north-bridge-infra-modernization
Northbridge Logistics runs its customer-facing services on Amazon EKS. The current cluster was set up mostly by hand, and add-ons such as the load balancer controller, storage drivers and monitoring were installed with Helm from engineers' laptops.  The cluster works, but the setup is difficult to repeat consistently. 
