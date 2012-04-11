CREATE TABLE PROC_TBL
(
  PROC_PID      NUMBER(10)                      NOT NULL,
  PROC_NAME     VARCHAR2(60),
  MACHINE_NAME  VARCHAR2(60),
  ACT_TOTAL     NUMBER(10),
  ACT_RATE      NUMBER(10),
  PROC_TEXT     VARCHAR2(4000),
  DELETED_FLG   NUMBER(1),
  MODIFIED_TM   DATE,
  CREATED_TM    DATE
)
