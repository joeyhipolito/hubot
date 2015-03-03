# Description:
#
#   Have Hubot remind you to do standups.
#   hh:mm must be in the same timezone as the server Hubot is on. Probably UTC.
#
#   This is configured to work for Hipchat. You may need to change the 'create standup' command
#   to match the adapter you're using.
#
# Disclaimer:
#   Shameless copy of https://github.com/hubot-scripts/hubot-standup-alarm/
#   modified for learning purposes
#
# Commands:
#   hubot standup help - See a help document explaining how to use.
#   hubot create standup hh:mm - Creates a standup at hh:mm every weekday for this room
#   hubot list standups - See all standups for this room
#   hubot list standups in every room - See all standups in every room
#   hubot delete hh:mm standup - If you have a standup at hh:mm, deletes it
#   hubot delete all standups - Deletes all standups for this room.
#
# Dependencies:
#   underscore
#   cron

_       = require 'lodash'
cronJob = require('cron').CronJob

module.exports = (robot) ->

  STANDUP_MESSAGES = [
    "Standup guys!"
    "Standup time!"
    "What the f* are you doing, standup time!"
    "Stop whatever you are doing, standup!"
    "Go go go standup!"
    "Okay standup"
    "Stop! And standup!"
  ]

  CREATE_STANDUP_MESSAGES = [
    "Okay, will remind you to do a standup on weekdays at "
    "https://dl.dropboxusercontent.com/u/233733589/hubot/alluka_kay.png , o...kay... standup set for all weekdays at "
    "standup saved, happens every weekday at "
  ]

  # check for standups to be fired once a minute ('1 * ...)
  # From Monday to Friday (... * 1-5')
  standupCronJob = new cronJob('1 * * * * 1-5', () ->
    checkStandups()
  , null, true)

  checkStandups = () ->
    standups = getStandups()

    _(standups).forEach((standup) ->
      if shouldStandUpFire(standup.time)
        doStandup standup.room
    )


  # compares current time to the assigned time for standup
  # check if it should be fired
  shouldStandUpFire = (standupTime) ->
    now = new Date()
    currentHours   = now.getHours()
    currentMinutes = now.getMinutes()

    standUpHours   = parseInt(standupTime.getHours())
    standupMinutes = parseInt(standupTime.getMinutes())

    if standUpHours is currentHours and standupMinutes is currentMinutes
      true

    false

  # create standups

  createStandup = (room, time) ->
    allStandups = getStandups()
    newStandUp = {
      time: time,
      room: room
    }
    allStandups.push newStandUp
    updateBrain(allStandups)

  getStandups = ->
    robot.brain.get 'standups' || []

  getStandupsForARoom  = (room) ->
    allStandups      = getStandups()
    standupsForARoom = []
    _(allStandups).forEach((standup) ->
      standupsForARoom.push standup if standup is room
    )

    standupsForARoom

  doStandup = (room) ->
    message = _.sample STANDUP_MESSAGES
    robot.message room, message

  updateBrain = (standups) ->
    robot.brain.set 'standups', standups

  removeAllStandupsForARoom = (room) ->
    allStandups     = getStandups()
    standupsToKeep  = []
    standupsRemoved = 0
    _(allStandups).forEach((standup) ->
      if standup.room is not room
        standupsToKeep.push standup
      else
        standupsRemoved++
    )
    updateBrain(standupsToKeep)
    return standupsRemoved

  removeSpecificStandupForARoom = (room, time) ->
    allStandups     = getStandups()
    standupsToKeep  = []
    standupsRemoved = 0
    _(allStandups).forEach((standup) ->
      if standup.room is room and standup.time is tim
        standupsRemoved++
      else
        standupsToKeep.push standup
    )
    updateBrain(standupsToKeep)
    return standupsRemoved

  getRoom = (msg) ->
    room = msg.envelope.user.reply_to
    if robot.adapterName == 'slack'
      room = msg.envelope.user.room
    return room

  # now listen to messages

  robot.respond /delete all standups/i, (msg) ->
    room = getRoom msg
    countOfRemovedStandups = removeAllStandupsForARoom room
    msg.send("Removed #{countOfRemovedStandups} standup" + (if standupsCleared == 1 then '' else 's') )

  robot.respond /delete (([01]?[0-9]|2[0-3]):[0-5][0-9]) standup/i, (msg) ->
    room = getRoom msg
    time = msg.match[1]
    countOfRemovedStandups = removeSpecificStandupForARoom room, time
    if countOfRemovedStandups is 0
      msg.send "Nice try. But you don't even have a standup at #{time}"
    else
      msg.send "Deleted your #{time} standup."

  robot.respond /create standup (([01]?[0-9]|2[0-3]):[0-5][0-9])$/i, (msg) ->
    time = msg.match[1]
    room = getRoom msg

    createStandup room, time
    msg.send _.sample(CREATE_STANDUP_MESSAGES) + time

  robot.respond /list standups$/i, (msg) ->
    room     = getRoom msg
    standups = getStandupsForARoom room

    message = "Pfft :no_mouth:, awkward.... room doesn't have any standups, yet."
    if standups.length is not 0
      standupsText = []
      standupsText.push "Here's your standups:"
      _(standups).forEach((standup) ->
        standupsText.push(standup.time)
      )
      message = standupsText.join("\n")

    msg.send message

  robot.respond /list standups in all room/i, (msg) ->
    standups = getStandups()
    message  = "There aren't any standups, in this whole wide slackers' world"
    if standups.length is not 0
      standupsText = []
      standupsText.push "Here's all the standups in all rooms:"
      _(standups).forEach((standup) ->
        standupsText.push "Room: #{standup.room}, Time: #{standup.time}"
      )
      message = standupsText.join '\n'

    msg.send message

  robot.respond /standup help/i, (msg) ->
    message = []
    message.push "I can remind your daily standups"
    message.push "Just tell me when, and I'll prompt you every weekday"
    message.push ""
    message.push "#{robot.name} create standup hh:mm - I'll remind you to do your standup at hh:mm every weekday"
    message.push "#{robot.name} list standups, I'll show you all standups in this room"
    message.push "#{robot.name} delete hh:mm standup, if you have a standup at hh:mm, I'll remove it"
    msg.send message.join '\n'


