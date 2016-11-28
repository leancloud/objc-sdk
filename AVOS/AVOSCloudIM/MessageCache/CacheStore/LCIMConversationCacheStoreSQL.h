//
//  LCIMConversationCacheStoreSQL.h
//  AVOS
//
//  Created by Tang Tianyong on 8/29/15.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#ifndef AVOS_LCIMConversationCacheStoreSQL_h
#define AVOS_LCIMConversationCacheStoreSQL_h

/*!
 * 3.7.3版本后，conversation缓存多了lastMessage字段
 */
#define LCIM_TABLE_CONVERSATION_VERSION @"V1.0"
#define LCIM_TABLE_CONVERSATION         @"conversation" @"-" LCIM_TABLE_CONVERSATION_VERSION

#define LCIM_FIELD_CONVERSATION_ID      @"conversation_id"
#define LCIM_FIELD_NAME                 @"name"
#define LCIM_FIELD_CREATOR              @"creator"
#define LCIM_FIELD_TRANSIENT            @"transient"
#define LCIM_FIELD_MEMBERS              @"members"
#define LCIM_FIELD_ATTRIBUTES           @"attr"
#define LCIM_FIELD_CREATE_AT            @"create_at"
#define LCIM_FIELD_UPDATE_AT            @"update_at"
#define LCIM_FIELD_LAST_MESSAGE_AT      @"last_message_at"
#define LCIM_FIELD_LAST_MESSAGE         @"last_message"
#define LCIM_FIELD_MUTED                @"muted"
#define LCIM_FIELD_EXPIRE_AT            @"expire_at"

#define LCIM_SQL_CREATE_CONVERSATION_TABLE \
    @"CREATE TABLE IF NOT EXISTS " LCIM_TABLE_CONVERSATION @" ("  \
        LCIM_FIELD_CONVERSATION_ID      @" TEXT, "                \
        LCIM_FIELD_NAME                 @" TEXT, "                \
        LCIM_FIELD_CREATOR              @" TEXT, "                \
        LCIM_FIELD_TRANSIENT            @" INTEGER, "             \
        LCIM_FIELD_MEMBERS              @" TEXT, "                \
        LCIM_FIELD_ATTRIBUTES           @" BLOB, "                \
        LCIM_FIELD_CREATE_AT            @" REAL, "                \
        LCIM_FIELD_UPDATE_AT            @" REAL, "                \
        LCIM_FIELD_LAST_MESSAGE_AT      @" REAL, "                \
        LCIM_FIELD_LAST_MESSAGE         @" BLOB, "                \
        LCIM_FIELD_EXPIRE_AT            @" REAL, "                \
        @"PRIMARY KEY(" LCIM_FIELD_CONVERSATION_ID @")"           \
    @")"

#define LCIM_SQL_INSERT_CONVERSATION                           \
    @"INSERT OR REPLACE INTO " LCIM_TABLE_CONVERSATION  @" ("  \
        LCIM_FIELD_CONVERSATION_ID      @", "                  \
        LCIM_FIELD_NAME                 @", "                  \
        LCIM_FIELD_CREATOR              @", "                  \
        LCIM_FIELD_TRANSIENT            @", "                  \
        LCIM_FIELD_MEMBERS              @", "                  \
        LCIM_FIELD_ATTRIBUTES           @", "                  \
        LCIM_FIELD_CREATE_AT            @", "                  \
        LCIM_FIELD_UPDATE_AT            @", "                  \
        LCIM_FIELD_LAST_MESSAGE_AT      @", "                  \
        LCIM_FIELD_LAST_MESSAGE         @", "                  \
        LCIM_FIELD_MUTED                @", " /* Version 1 */  \
        LCIM_FIELD_EXPIRE_AT                                   \
    @") VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"

#define LCIM_SQL_DELETE_CONVERSATION              \
    @"DELETE FROM " LCIM_TABLE_CONVERSATION @" "  \
    @"WHERE " LCIM_FIELD_CONVERSATION_ID @" = ?"

#define LCIM_SQL_SELECT_CONVERSATION                \
    @"SELECT * FROM " LCIM_TABLE_CONVERSATION @" "  \
    @"WHERE " LCIM_FIELD_CONVERSATION_ID @" = ?"

#define LCIM_SQL_SELECT_EXPIRED_CONVERSATIONS       \
    @"SELECT * FROM " LCIM_TABLE_CONVERSATION @" "  \
    @"WHERE " LCIM_FIELD_EXPIRE_AT @" <= ?"

#define LCIM_SQL_SELECT_ALIVE_CONVERSATIONS         \
    @"SELECT * FROM " LCIM_TABLE_CONVERSATION @" "  \
    @"WHERE " LCIM_FIELD_EXPIRE_AT @" > ?"

#endif
