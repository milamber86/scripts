#!/bin/bash
if [ -n "$SSH_ORIGINAL_COMMAND" ]; then
    if [[ "$SSH_ORIGINAL_COMMAND" =~ ^rsync\  ]]; then
        echo "`/bin/date`: $SSH_ORIGINAL_COMMAND" >> $HOME/ssh-command-log
        exec $SSH_ORIGINAL_COMMAND
    else
        echo "`/bin/date`: DENIED $SSH_ORIGINAL_COMMAND" >> $HOME/ssh-command-log
    fi
fi
