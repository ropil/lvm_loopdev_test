#!/bin/bash

sudo watch -n 10 lvs -a -o name,raid_sync_action,sync_percent,raid_mismatch_count,lv_health_status,attr
