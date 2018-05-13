# AWS Route53 Dynamic DNS Add-on for Hass.io (Home Assistant)

## Introduction

This repo contains a Home Assistant add-on that add's AWS Route53 dynamic DNS support.

When using this, you can provide the plugin a set of AWS credentials and other information and have it manage a DNS record of your choice that represents your IP address.

It is handy for home environments with dynamic IP addresses that you need to keep updated in DNS and you already use Route 53 already.

If you are unfamiliar with Home Assistant, check out the below links;
-  [Home Assistant](https://home-assistant.io/hassio)
-  [Home Assistant Add-on development documentation](https://developers.home-assistant.io/docs/en/hassio_addon_index.html)

This add-on assumes that you are familiar with AWS and Route 53. If you are not, I'd suggest checking out the documentation first.

Behind the scenes, it is written in bash and uses the AWS CLI to create, update and determine the state of your Route53 records.

## AWS Route 53 configuration
On the AWS side, you need to do the following;
1. Create a suitable zone for a domain that you own and manage in Route53, in this example, I'm using the domain ```home.yourdomain.com``` as this example.
2. Once created, note down the ```Hosted Zone ID``` value for the domain we will need this for the plugin configuration and for IAM configuration
3. Create an IAM Policy that provides update and query access to this domain explicitly and has no other permissions to the AWS account.

Here is an IAM Policy sample that I put together, dont' forget to update your Zone ID on the Resource line.

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "route53:GetHostedZone",
                "route53:ChangeResourceRecordSets",
                "route53:ListResourceRecordSets"
            ],
            "Resource": "arn:aws:route53:::hostedzone/YOURZONEIDGOESHERE"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "route53:TestDNSAnswer",
            "Resource": "*"
        }
    ]
}
```

4. Once this has been done, create a new user called ```homeassistant``` and add the IAM policy to the user, allowing it to manage this DNS resource
5. Under the security credentials tab for the ```homeassistant``` user, create a set of access keys for placement in the add-on configuration JSON

## Home Assistant Configuration
Now that we have the AWS side configured, we need to setup the hass.io side.

1. Login to your home assistant web interface and click the ```hass.io``` button on the left hand side
2. Click ```Add-on Store``` at the top of the ```Hass.io``` menu
3. Paste ```https://github.com/keirans/hassio_route53``` into the  ```Add new repository by URL``` box at the top and click ```Add```
4. You will see that at the very bottom of the add-on screen there is a new add on available called ```Route53 Home Assistant Add-on```, select this and click ```Install```
5. The plugin will then build, this can take up to 5 mins and then once done will present you with the configuration screen. In the config box, paste your AWS configuration information in JSON format using the below schema and click save. Note that you need to specify the A record that you want the add-on to create and manage, in this case it is ```hassio.home.yourdomain.com```.

```
{
  "AWS_ACCESS_KEY_ID": "YOURACCESSKEY",
  "AWS_SECRET_ACCESS_KEY": "YOURSECRETKEY",
  "AWS_REGION": "ap-southeast-2",
  "ZONEID": "YOURZONEID",
  "RECORDNAME": "hassio.home.yourdomain.com",
  "TIMEOUT": 500,
  "DEBUG": "false",
  "IPURL": "https://api.ipify.org?format=text"
}
```
6. Click the Start button and the plugin will start, and create and manage the record in your domain.


The below example output shows the plugin starting and creating the first record for your domain.

```
[s6-init] making user provided files available at /var/run/s6/etc...exited 0.
[s6-init] ensuring user provided files have correct perms...exited 0.
[fix-attrs.d] applying ownership & permissions fixes...
[fix-attrs.d] done.
[cont-init.d] executing container initialization scripts...
[cont-init.d] 00-banner.sh: executing... 
-----------------------------------------------------------
 Hass.io Add-on: Route53 Dynamic DNS v1.0
 AWS Route53 Dynamic DNS Add-on for Home Assistant
 From: Route53 Home Assistant Add-on
 By: Keiran Sweet <keiran@gmail.com>
-----------------------------------------------------------
[cont-init.d] 00-banner.sh: exited 0.
[cont-init.d] 01-log-level.sh: executing... 
[cont-init.d] 01-log-level.sh: exited 0.
[cont-init.d] 02-updates.sh: executing... 
[15:04:36+1000] INFO ----> You are running the latest version of this add-on
[cont-init.d] 02-updates.sh: exited 0.
[cont-init.d] done.
[services.d] starting services
[services.d] done.
Sun May 13 15:04:44 AEST 2018 INFO : Got NXDOMAIN ("NXDOMAIN") - Creating new A Record
Sun May 13 15:04:44 AEST 2018 INFO : Updating / Creating the A record for hassio.home.yourdomain.com in Zone Z3QGSU4OABCKJ2
{
    "ChangeInfo": {
        "Id": "/change/C2NVQSQUKABCDE",
        "Status": "PENDING",
        "SubmittedAt": "2018-05-13T05:04:48.153Z",
        "Comment": "Home Assistant "
    }
}

```

The following output shows the record being updated after the address has been determined to have changed.

```
Sun May 13 15:13:14 AEST 2018 INFO : Got NOERROR ("NOERROR") - Continue to ensure IP address is correct in record
Sun May 13 15:13:19 AEST 2018 INFO : The Addresses don't match (69.234.69.81 is not the same as 127.0.0.1) - Updating record
Sun May 13 15:13:19 AEST 2018 INFO : Updating / Creating the A record for hassio.home.yourdomain.com in Zone Z3QGSU4OABCKJ2
{
    "ChangeInfo": {
        "Id": "/change/C1QX0Z0X1234WU",
        "Status": "PENDING",
        "SubmittedAt": "2018-05-13T05:13:23.616Z",
        "Comment": "Home Assistant "
    }
}
```



## Debugging and additional configuration
- If you have any issues, set the DEBUG value in the config to 'true' and you will get more information about the execution.
- If you don't want to determine your IP address from ipify.com, you can replace the IPURL value in the config with any URL that will return your IP address as a string.


## Important security considerations
- Please familiarise yourself with the security implications of AWS API keys and ensure that you store them securely and have them associated with an IAM role that only provides access to the specific resources that this plugin needs to create and update (The Route53 zone you are using for Dynamic DNS)
- You don't have to create a subdomain for your Home Assistant DNS record, however, doing so allows your IAM Policy to be tightly bound to a subset of Route 53 records, limiting any issues in the event that your keys are compromised.
- This document details the basics of getting the plugin up and running, I advise you to add additional layers of security where you can such as adding IAM conditionals to ensure that the API keys can only be used from the IP address block of your ISP.
- If you are managing your hass.io configuration as code, take care not to expose your API keys to the world via pushing to public git platform such as github.
- Unfortunately, at this stage, hassio add-ons cannot leverage Home Assistant's secrets repository functionality, so this is the only way we can handle the API keys at this stage.

## Misc bits and peices
- This plugin was coded on a rainy Sunday afternoon, as such it is provided as is, however if you find a bug, i'll happilly accept pull requests
- I initially wrote this plugin in Ruby with the AWS Ruby SDK, however I found that it was more reliable to use the hass.io base images and helpers as well as being able to get community support when I had issues.
- I've only tested this on hass.io on a Raspberry Pi 3, however it should function on all platform that can build and run add-ons
