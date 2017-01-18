//
//  LCIMMessageReceiptCacheStoreSQL.h
//  AVOS
//
//  Created by 陈宜龙 on 06/01/2017.
//  Copyright © 2017 LeanCloud Inc. All rights reserved.
//  用来存储对话中某人接收到的最新的回执情况：已读、已接收的时间戳

#ifndef LCIMMessageReceiptCacheStoreSQL_h
#define LCIMMessageReceiptCacheStoreSQL_h

#define LCIM_TABLE_MESSAGE_RCP          @"message_rcp"

#define LCIM_FIELD_CONVERSATION_ID      @"conversation_id"
#define LCIM_FIELD_RECEIPT_TIMESTAMP    @"receipt_timestamp"
#define LCIM_FIELD_READ_TIMESTAMP       @"read_timestamp"
#define LCIM_FIELD_STATUS               @"status"

#define LCIM_SQL_CREATE_MESSAGE_RCP_TABLE                                 \
    @"CREATE TABLE IF NOT EXISTS " LCIM_TABLE_MESSAGE_RCP @" ("  \
        LCIM_FIELD_CONVERSATION_ID                      @" TEXT, "    \
        LCIM_FIELD_STATUS                               @" INTEGER, " \
        LCIM_FIELD_RECEIPT_TIMESTAMP                    @" NUMBERIC, "\
        LCIM_FIELD_READ_TIMESTAMP                       @" NUMBERIC, "\
        @"PRIMARY KEY(" LCIM_FIELD_CONVERSATION_ID  @", " LCIM_FIELD_STATUS @") ON CONFLICT IGNORE"          \
    @")"

#define LCIM_SQL_INSERT_MESSAGE_RCP                                  \
    @"INSERT OR REPLACE INTO " LCIM_TABLE_MESSAGE_RCP  @" ("          \
        LCIM_FIELD_CONVERSATION_ID      @", "                    \
        LCIM_FIELD_STATUS               @", "                    \
        LCIM_FIELD_RECEIPT_TIMESTAMP    @", "                    \
        LCIM_FIELD_READ_TIMESTAMP                                \
    @") VALUES(?, ?, ?, ?)"

#define LCIM_SQL_MESSAGE_RCP_WHERE_CLAUSE              \
    @"WHERE " LCIM_FIELD_CONVERSATION_ID @" = ? "  \
    @"AND " LCIM_FIELD_STATUS            @" = ?"

#define LCIM_SQL_UPDATE_MESSAGE_RCP          \
    @"UPDATE " LCIM_TABLE_MESSAGE_RCP    @" "\
    @"SET "                                       \
        LCIM_FIELD_RECEIPT_TIMESTAMP    @" = ?, " \
        LCIM_FIELD_READ_TIMESTAMP       @" = ?, " \
    LCIM_SQL_MESSAGE_RCP_WHERE_CLAUSE


#define LCIM_SQL_SELECT_MESSAGE_RCP_BY_ID                 \
    @"SELECT * FROM " LCIM_TABLE_MESSAGE_RCP @" "\
    LCIM_SQL_MESSAGE_RCP_WHERE_CLAUSE

#define LCIM_SQL_SELECT_READ_TIMESTAMP                                               \
    @"SELECT " LCIM_FIELD_READ_TIMESTAMP @" FROM " LCIM_TABLE_MESSAGE_RCP @" "  \
    LCIM_SQL_MESSAGE_RCP_WHERE_CLAUSE

#define LCIM_SQL_SELECT_RECEIPT_TIMESTAMP                                               \
    @"SELECT " LCIM_FIELD_RECEIPT_TIMESTAMP @" FROM " LCIM_TABLE_MESSAGE_RCP @" "  \
    LCIM_SQL_MESSAGE_RCP_WHERE_CLAUSE

#define LCIM_SQL_DELETE_CONVERSATION              \
    @"DELETE FROM " LCIM_TABLE_MESSAGE_RCP @" "  \
    @"WHERE " LCIM_FIELD_CONVERSATION_ID @" = ?"

#endif /* LCIMMessageReceiptCacheStoreSQL_h */
