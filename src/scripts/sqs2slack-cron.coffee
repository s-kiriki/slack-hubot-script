# Description:
#  Send messages in SQS to Slack channel by cron.
#
# Dependencies:
#   "aws-sdk": "^2.0.21"
#   "cron": "^1.0.5"
#	"hubot-slack": "^2.2.0"
#
# Configuration:
#   [Required]
#     HUBOT_AWS_ACCESS_KEY_ID
#     HUBOT_AWS_SECRET_ACCESS_KEY
#     HUBOT_SQS2SLACK_QUEUE_NAME
#   [Optional]
#     HUBOT_AWS_SQS_REGION ( default is 'ap-northeast-1')
#     HUBOT_SQS2SLACK_CHANNEL ( default is '#general' )
#     HUBOT_SQS2SLACK_CRON_TIMER ( default is '*/10 * * * *' )
#     HUBOT_SQS2SLACK_CRON_TIMEZONE ( default is 'Asia/Tokyo' )
#     HUBOT_SQS2SLACK_MAX_MSG ( default is 5 )
#     HUBOT_SQS2SLACK_WAIT_SEC ( default is 0 )
#
# Author:
#   s-kiriki

module.exports = (robot) ->

	channelName = process.env.HUBOT_SQS2SLACK_CHANNEL || '#general'

	if !process.env.HUBOT_AWS_ACCESS_KEY_ID
		return robot.messageRoom channelName, 'You must set ENV: HUBOT_AWS_ACCESS_KEY_ID'
		
	if !process.env.HUBOT_AWS_SECRET_ACCESS_KEY
		return robot.messageRoom channelName, 'You must set ENV: HUBOT_AWS_SECRET_ACCESS_KEY'
		
	if !process.env.HUBOT_SQS2SLACK_QUEUE_NAME
		return robot.messageRoom channelName, 'You must set ENV: HUBOT_SQS2SLACK_QUEUE_NAME'
		
	AWS = require("aws-sdk")
	CronJob = require('cron').CronJob
	
	sqsRegion = process.env.HUBOT_AWS_SQS_REGION || 'ap-northeast-1'
	cronTimer = process.env.HUBOT_SQS2SLACK_CRON_TIMER || '*/10 * * * *'
	cronTimezone = process.env.HUBOT_SQS2SLACK_CRON_TIMEZONE || 'Asia/Tokyo'
	maxNumberOfMessages = process.env.HUBOT_SQS2SLACK_MAX_MSG || 5
	waitTimeSeconds = process.env.HUBOT_SQS2SLACK_WAIT_SEC || 0
	
	new CronJob(cronTimer, () ->
		sendMsgSqs2Slack()
	, null, true, cronTimezone)

	sendMsgSqs2Slack = ()->
		sqs = new AWS.SQS({apiVersion: '2012-11-05', accessKeyId: process.env.HUBOT_AWS_ACCESS_KEY_ID, secretAccessKey: process.env.HUBOT_AWS_SECRET_ACCESS_KEY, region: sqsRegion})
		params = {QueueName: process.env.HUBOT_SQS2SLACK_QUEUE_NAME}
		
		sqs.getQueueUrl(params, (err, data) ->
			if (err)
				robot.messageRoom channelName, 'Error occured on get SQS queue'
			else
				queueUrl = data.QueueUrl
				msgReceiveParams = {
					QueueUrl: queueUrl,
					MaxNumberOfMessages: maxNumberOfMessages
					WaitTimeSeconds: waitTimeSeconds
				}
				sqs.receiveMessage(msgReceiveParams, (err, data) ->
					if (err)
						robot.messageRoom channelName, 'Error occured on receiving SQS messages'
					else
						if data.Messages?
							entries = []
							for message, key in data.Messages
								body = JSON.parse(message.Body)
								entries.push {Id:"#{key+1}", ReceiptHandle:message.ReceiptHandle}
								msgSendChannelName = body.channel || channelName
								robot.messageRoom msgSendChannelName, "*#{body.title}*\n#{body.message}"
							
							if entries.length > 0
								msgDeleteParams = {Entries: entries, QueueUrl: queueUrl}
								sqs.deleteMessageBatch(msgDeleteParams, (err, data) ->
									if (err)
										robot.messageRoom channelName, 'Error occured on deleting SQS messages'
								)
				);
		);
