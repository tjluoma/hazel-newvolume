#!/bin/zsh -f
# Purpose: Script that acts on new volumes mounted in /Volumes/
#
# From:	Tj Luo.ma
# Mail:	luomat at gmail dot com
# Web: 	http://RhymesWithDiploma.com
# Date:	2013-12-30

NAME="$0:t:r"

APP_NAME='HazelHelper'
BUNDLE_ID='com.noodlesoft.hazelhelper'

zmodload zsh/datetime

function msg {

	TIME=$(strftime "%Y-%m-%d @ %H.%M.%S" "$EPOCHSECONDS")

	if (( $+commands[terminal-notifier] ))
	then
			terminal-notifier \
				-message "$@" \
					-sender "${BUNDLE_ID}" \
					-title "${NAME}" \
					-subtitle "${TIME}" \
					-execute "open -a 'Finder' '/Applications/'"
	fi

	echo "$NAME: $@"
}

unmount_dmg () {

		MNTPATH="$@"

		MAX_ATTEMPTS="10"

		SECONDS_BETWEEN_ATTEMPTS="5"

			# strip away anything that isn't a 0-9 digit
		SECONDS_BETWEEN_ATTEMPTS=$(echo "$SECONDS_BETWEEN_ATTEMPTS" | tr -dc '[0-9]')
		MAX_ATTEMPTS=$(echo "$MAX_ATTEMPTS" | tr -dc '[0-9]')

			# initialize the counter
		COUNT=0

			# NOTE this 'while' loop can be changed to something else
		while [ -e "$MNTPATH" ]
		do

				# increment counter (this is why we init to 0 not 1)
			((COUNT++))

				# check to see if we have exceeded maximum attempts
			if [ "$COUNT" -gt "$MAX_ATTEMPTS" ]
			then

				msg "Exceeded $MAX_ATTEMPTS"

				break
			fi

				# don't sleep the first time through the loop
			[[ "$COUNT" != "1" ]] && sleep ${SECONDS_BETWEEN_ATTEMPTS}

			# Do whatever you want to do in the 'while' loop here
			diskutil unmount "$MNTPATH" && msg "${MNTPATH} unmounted"

		done
}


pgrep -iq 'MacUpdate Desktop' && msg "Quitting because MacUpdate Desktop is running" && exit 0


APP_INSTALL_DIR='/Applications'

for ARGS in "$@"
do
	case "$ARGS" in
		-a|--a)

				shift
		;;

		-b|--b)
				shift
		;;

		-*|--*)
				msg "[info]: Don't know what to do with arg: $1"
				shift
		;;

	esac

done # for args

for VOLUME in "$@"
do

		if { command mount | fgrep "$VOLUME" | sed "s#.*${VOLUME} ##g" | fgrep -q 'read-only' }
		then
					# If we get here, this a read-only disk like a DMG
				:

		else
					# This is not a read-only disk
					# Skip the rest of this and go on to the next item in the $@ if there are any
				continue
		fi

		# If we get here, we are in a read-only drive, probably DMG

		(find ${VOLUME}/* -maxdepth 1 \( -iname \*.pkg -o -iname \*.app -o -iname \*.mpkg \) -print ||\
		find ${VOLUME}/* -maxdepth 2 \( -iname \*.pkg -o -iname \*.app -o -iname \*.mpkg \) -print) |\
		while read line
		do

				case "$line:e:l" in
					app)
								msg "Installing $line:t"

									# Check to make sure the app isn't an installer, if it is, open it instead
								case "$line:t:r:l" in
									*install*)
													msg "$line:t is an installer"

														# Open the installer and WAIT for it to finish
													open -W "$line"
													exit
									;;

									*)
										APPNAME="$line:t"
										msg "${APPNAME} is NOT an installer"

										# Is the app already installed?

										if [ -e "$APP_INSTALL_DIR/$APPNAME" ]
										then
												# Yes the app is installed already
												# Now we have to see if the app is running

												# `pgrep` is only standard in 10.8 and later I think

												# PIDS=$(pgrep -f "${APP_INSTALL_DIR}/${APPNAME}")

												PIDS=($(pgrep -d ' ' -f "${APPNAME}"))

												while [ "$PIDS" != "" ]
												do
																# FIXME/BUG/LIMITATION: if the app does not quit, we'll be stuck here forever
														PID="$PIDS[1]"

														for RUNNINGAPP in `ps -o command= ${PID} | tr '/' '\012' | egrep '\.app$' | tail -1 | sed -e 's/\.app$//'`
														do
																osascript -e "tell application \"$RUNNINGAPP\" to quit"
																sleep 5 # give it a chance to quit
														done

														# Check to see if we still have any PIDS left

														PIDS=($(pgrep -d ' ' -f "${APPNAME}"))

												done

											# OK, now it should be quit already, so now we need to move it out of the way


											# Who owns the file?

											zmodload zsh/stat

											APP_UID=`zstat +uid "$APP_INSTALL_DIR/$APPNAME"`

											if [ "$UID" = "$APP_UID" ]
											then
														# IS owned by current user
														# osascript -e "tell app \"Finder\" to delete POSIX file \"\""

													osascript -e "tell application \"Finder\" to delete POSIX file \"$APP_INSTALL_DIR/$APPNAME\"" ||\
													mv -f "$APP_INSTALL_DIR/$APPNAME" "$HOME/.Trash/"



											else
														# Not owned by current user
														# osascript -e "tell app \"Finder\" to delete POSIX file \"${PWD}/$b\""
													osascript -e "tell app \"Finder\" to delete POSIX file \"$APP_INSTALL_DIR/$APPNAME\" with administrator privileges" ||\
													sudo mv -f "$APP_INSTALL_DIR/$APPNAME" "$HOME/.Trash/"

											fi # if the app is owned by this user


										fi # if app is already installed

										# ditto -v "$MNTPNT/Spotify/Spotify.app" "/Applications/Spotify.app"

										if [ -e "$APP_INSTALL_DIR/$APPNAME" ]
										then
												msg "Cannot install $line:t because it still exists in $APP_INSTALL_DIR"
												exit 1
										fi

											# here is where we actually install the app

											if { command ditto "${line}" "${APP_INSTALL_DIR}/${APPNAME}"  }
											then

														# Tell the user we have succeeded
													msg "Installed $line:t to $APP_INSTALL_DIR"

											else

													msg "Failed to install $line to $APP_INSTALL_DIR"

													exit 1
											fi



											# Reveal the installed file
										open -R "$APP_INSTALL_DIR/$APPNAME"

											# make sure were are not in the DMG's PATH
										cd /

										unmount_dmg "$VOLUME"

									;;

								esac
					;;

					pkg|mpkg)
								msg "[TODO] Package install of $line"

					;;

					*)
								msg "[TODO]: I don't know what to do with EXT = $line:e:l"
					;;

				esac
		done
done



exit
#
#EOF
