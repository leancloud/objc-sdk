//
//  LCIMMessageCacheSQL.h
//  AVOS
//
//  Created by Tang Tianyong on 5/12/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#ifndef AVOS_LCIMMessageCacheSQL_h
#define AVOS_LCIMMessageCacheSQL_h

#define LCIM_TABLE_MESSAGE              @"message"

#define LCIM_FIELD_MESSAGE_ID           @"message_id"
#define LCIM_FIELD_CONVERSATION_ID      @"conversation_id"
#define LCIM_FIELD_FROM_PEER_ID         @"from_peer_id"
#define LCIM_FIELD_TIMESTAMP            @"timestamp"
#define LCIM_FIELD_RECEIPT_TIMESTAMP    @"receipt_timestamp"
#define LCIM_FIELD_READ_TIMESTAMP       @"read_timestamp"
#define LCIM_FIELD_PATCH_TIMESTAMP      @"patch_timestamp"
#define LCIM_FIELD_PAYLOAD              @"payload"
#define LCIM_FIELD_BREAKPOINT           @"breakpoint"
#define LCIM_FIELD_STATUS               @"status"

#define LCIM_INDEX_MESSAGE              @"unique_index"

#define LCIM_SQL_SELECT_NEXT_MESSAGE \
@"select * from message where conversation_id = ? and (timestamp > ? or (timestamp = ? and message_id > ?)) order by timestamp, message_id limit 1"

#define LCIM_SQL_INSERT_MESSAGE \
@"insert or replace into message (message_id, conversation_id, from_peer_id, mention_all, mention_list, timestamp, receipt_timestamp, read_timestamp, patch_timestamp, payload, status, breakpoint) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"

#define LCIM_SQL_REPLACE_MESSAGE \
@"replace into message (seq, message_id, conversation_id, from_peer_id, mention_all, mention_list, timestamp, receipt_timestamp, read_timestamp, patch_timestamp, payload, status, breakpoint) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"

#define LCIM_SQL_UPDATE_MESSAGE \
@"update message set from_peer_id = ?, mention_all = ?, mention_list = ?, timestamp = ?, receipt_timestamp = ?, read_timestamp = ?, patch_timestamp = ?, payload = ?, status = ? where conversation_id = ? and message_id = ?"

#define LCIM_SQL_DELETE_MESSAGE \
@"delete from message where conversation_id = ? and (seq = ? or (message_id is not null and message_id = ?))"

#define LCIM_SQL_UPDATE_MESSAGE_BREAKPOINT \
@"update message set breakpoint = ? where conversation_id = ? and message_id = ?"

#define LCIM_SQL_SELECT_MESSAGE_LESS_THAN_TIMESTAMP \
@"select * from message where conversation_id = ? and timestamp < ? order by timestamp desc limit ?"

#define LCIM_SQL_CREATE_MESSAGE_TABLE \
@"create table if not exists message (message_id text, conversation_id text, from_peer_id text, timestamp real, receipt_timestamp real, payload blob, status integer, breakpoint bool, primary key(message_id))"

#define LCIM_SQL_SELECT_MESSAGE_BY_ID \
@"select * from message where conversation_id = ? and message_id = ?"

#define LCIM_SQL_DELETE_ALL_MESSAGES_OF_CONVERSATION \
@"delete from message where conversation_id = ?"

#define LCIM_SQL_CREATE_MESSAGE_UNIQUE_INDEX \
@"create unique index if not exists unique_index on message(conversation_id, message_id, timestamp)"

#define LCIM_SQL_LATEST_MESSAGE \
@"select * from message where conversation_id = ? order by timestamp desc limit ?"

#define LCIM_SQL_CLEAN_MESSAGE \
@"delete from message where conversation_id = ?"

#define LCIM_SQL_SELECT_MESSAGE_LESS_THAN_TIMESTAMP_AND_ID \
@"select * from message where conversation_id = ? and (timestamp < ? or (timestamp = ? and message_id < ?)) order by timestamp desc, message_id desc limit ?"

#define LCIM_SQL_LATEST_NO_BREAKPOINT_MESSAGE \
@"select *, max(timestamp) from message where conversation_id = ? and breakpoint = 0"

#define LCIM_SQL_UPDATE_MESSAGE_ENTRIES_FMT \
@"update message set %@ where conversation_id = ? and message_id = ?"

#define LCIM_SQL_MESSAGE_MIGRATION_V1 \
@"alter table conversation add column muted integer"

#define LCIM_SQL_MESSAGE_MIGRATION_V2 \
@"alter table message add column read_timestamp real"

#define LCIM_SQL_MESSAGE_MIGRATION_V3 \
@"alter table message add column patch_timestamp real"

/*
 1. Add an auto-increment primary key 'seq' as index for unsent message which the message id will change after sent.
 2. Add two mention related fields: 'mention_all' and 'mention_list'.
 */

#define LCIM_SQL_MESSAGE_MIGRATION_V4 \
@"create table if not exists message_seq(                                                                        \
    seq integer primary key autoincrement, message_id text,                                                      \
    conversation_id text, from_peer_id text, timestamp real,                                                     \
    receipt_timestamp real, read_timestamp real, patch_timestamp real,                                           \
    mention_all integer, mention_list blob,                                                                      \
    payload blob, status integer, breakpoint bool);                                                              \
                                                                                                                 \
create unique index if not exists message_unique_index on message_seq(conversation_id, message_id, timestamp);   \
                                                                                                                 \
create index if not exists message_index_conversation_id on message_seq(conversation_id);                        \
create index if not exists message_index_message_id on message_seq(message_id);                                  \
create index if not exists message_index_timestamp on message_seq(timestamp);                                    \
                                                                                                                 \
drop index if exists unique_index;                                                                               \
                                                                                                                 \
insert into message_seq(                                                                                         \
    message_id, conversation_id, from_peer_id, payload, timestamp,                                               \
    receipt_timestamp, read_timestamp, patch_timestamp, status, breakpoint)                                      \
select                                                                                                           \
    message_id, conversation_id, from_peer_id, payload, timestamp,                                               \
    receipt_timestamp, read_timestamp, patch_timestamp, status, breakpoint                                       \
from message order by timestamp asc, message_id asc;                                                             \
                                                                                                                 \
drop table if exists message;                                                                                    \
alter table message_seq rename to message;"

#define LCIM_SQL_LAST_MESSAGE_SEQ \
@"select seq from sqlite_sequence where name=\"message\""

#endif
