CREATE TABLE Duplicates AS
SELECT OWN_Email,
       Source.GRP_ID AS SRCGRP_ID,
       Source.GRPOWN_ID AS SRCOWN_ID,
       Dest.GRP_ID AS DSTGRP_ID,
       Dest.GRPOWN_ID AS DSTOWN_ID
FROM EventGroup SOURCE,
                EventGroup Dest,
                EventOwner orig
WHERE (Source.GrpLink IS NULL
       OR Source.GrpLink = '')
  AND OWN_ID = Source.GRPOWN_ID
  AND OWN_Email <> 'calendarservices'
  AND OWN_Email <> ''
  AND OWN_Email IS NOT NULL
  AND Source.GRPOWN_ID IN
    (SELECT GRPOWN_ID
     FROM EventGroup
     WHERE (GrpLink IS NULL
            OR GrpLink = '')
     GROUP BY GRPOWN_ID
     HAVING count(*) > 1
     UNION SELECT OWN_ID AS GRPOWN_ID
     FROM EventOwner
     WHERE OWN_Email IN
         (SELECT OWN_Email
          FROM EventOwner
          GROUP BY OWN_Email
          HAVING count(*) > 1))
  AND Dest.GRP_ID =
    (SELECT min(GRP_ID)
     FROM EventGroup,
          EventOwner
     WHERE GRPOWN_ID = OWN_ID
       AND OWN_Email = orig.OWN_Email
       AND (GrpLink IS NULL
            OR GrpLink = ''))
  AND Source.GRP_ID <>
    (SELECT min(GRP_ID)
     FROM EventGroup,
          EventOwner
     WHERE GRPOWN_ID = OWN_ID
       AND OWN_Email = orig.OWN_Email
       AND (GrpLink IS NULL
            OR GrpLink = ''));

ALTER TABLE duplicates ADD KEY srcownindex (`SRCOWN_ID`);
ALTER TABLE duplicates ADD KEY srcgrpindex (`SRCGRP_ID`);
ALTER TABLE duplicates ADD KEY dstownindex (`DSTOWN_ID`);
ALTER TABLE duplicates ADD KEY dstgrpindex (`DSTGRP_ID`);

UPDATE Event
JOIN Duplicates ON EvnModifiedOWN_ID = SRCOWN_ID AND EvnModifiedOWN_ID <> DSTOWN_ID
SET EvnModifiedOWN_ID = DSTOWN_ID;

UPDATE Event
JOIN Duplicates ON EvnLockOWN_ID = SRCOWN_ID AND EvnLockOWN_ID <> DSTOWN_ID
SET EvnLockOWN_ID = DSTOWN_ID;

UPDATE Event
JOIN Duplicates ON EvnOWN_ID = SRCOWN_ID AND EvnOWN_ID <> DSTOWN_ID
SET EvnOWN_ID = DSTOWN_ID;

UPDATE Event
JOIN Duplicates ON EVNGRP_ID = SRCGRP_ID
SET EVNGRP_ID = DSTGRP_ID;

UPDATE ContactItem
JOIN Duplicates ON ItmModifiedOWN_ID = SRCOWN_ID AND ItmModifiedOWN_ID <> DSTOWN_ID
SET ItmModifiedOWN_ID = DSTOWN_ID;

UPDATE ContactItem
JOIN Duplicates ON ItmLockOWN_ID = SRCOWN_ID AND ItmLockOWN_ID <> DSTOWN_ID
SET ItmLockOWN_ID = DSTOWN_ID;

UPDATE ContactItem
JOIN Duplicates ON ITMOWN_ID = SRCOWN_ID AND ITMOWN_ID <> DSTOWN_ID
SET ITMOWN_ID = DSTOWN_ID;

UPDATE ContactItem
JOIN Duplicates ON ITMGRP_ID = SRCGRP_ID
SET ITMGRP_ID = DSTGRP_ID;

UPDATE Folders
JOIN Duplicates ON FDRCREATOROWN_ID = SRCOWN_ID AND FDRCREATOROWN_ID <> DSTOWN_ID
SET FDRCREATOROWN_ID = DSTOWN_ID;

UPDATE Apitoken
JOIN Duplicates ON TOKOWN_ID = SRCOWN_ID AND TOKOWN_ID <> DSTOWN_ID
SET TOKOWN_ID = DSTOWN_ID;

UPDATE documenteditingstatus
JOIN Duplicates ON DESOWN_ID = SRCOWN_ID AND DESOWN_ID <> DSTOWN_ID
SET DESOWN_ID = DSTOWN_ID;

UPDATE documenteditingpermission
JOIN Duplicates ON DEPOWN_ID = SRCOWN_ID AND DEPOWN_ID <> DSTOWN_ID
SET DEPOWN_ID = DSTOWN_ID;

UPDATE eventcomment
JOIN Duplicates ON COMOWN_ID = SRCOWN_ID AND COMOWN_ID <> DSTOWN_ID
SET COMOWN_ID = DSTOWN_ID;

UPDATE eventcomment
JOIN Duplicates ON COMGRP_ID = SRCGRP_ID
SET COMGRP_ID = DSTGRP_ID;

UPDATE eventholiday
JOIN Duplicates ON HOLOWN_ID = SRCOWN_ID AND HOLOWN_ID <> DSTOWN_ID
SET HOLOWN_ID = DSTOWN_ID;

UPDATE eventmymention
JOIN Duplicates ON MENGRP_ID = SRCGRP_ID
SET MENGRP_ID = DSTGRP_ID;

UPDATE eventmyreaction
JOIN Duplicates ON REAOWN_ID = SRCOWN_ID AND REAOWN_ID <> DSTOWN_ID
SET REAOWN_ID = DSTOWN_ID;

UPDATE eventmyreaction
JOIN Duplicates ON REAGRP_ID = SRCGRP_ID
SET REAGRP_ID = DSTGRP_ID;

UPDATE eventpin
JOIN Duplicates ON PINOWN_ID = SRCOWN_ID AND PINOWN_ID <> DSTOWN_ID
SET PINOWN_ID = DSTOWN_ID;

UPDATE eventpin
JOIN Duplicates ON PINGRP_ID = SRCGRP_ID
SET PINGRP_ID = DSTGRP_ID;

UPDATE globaleventpin
JOIN Duplicates ON PINOWN_ID = SRCOWN_ID AND PINOWN_ID <> DSTOWN_ID
SET PINOWN_ID = DSTOWN_ID;

UPDATE globaleventpin
JOIN Duplicates ON PINGRP_ID = SRCGRP_ID
SET PINGRP_ID = DSTGRP_ID;

UPDATE groupchatunread
JOIN Duplicates ON GCUOWN_ID = SRCOWN_ID AND GCUOWN_ID <> DSTOWN_ID
SET GCUOWN_ID = DSTOWN_ID;

UPDATE groupchatunread
JOIN Duplicates ON GCUGRP_ID = SRCGRP_ID
SET GCUGRP_ID = DSTGRP_ID;

UPDATE onlinedocumentediting
JOIN Duplicates ON ODEOWN_ID = SRCOWN_ID AND ODEOWN_ID <> DSTOWN_ID
SET ODEOWN_ID = DSTOWN_ID;

UPDATE onlinedocumentediting
JOIN Duplicates ON ODEGRP_ID = SRCGRP_ID
SET ODEGRP_ID = DSTGRP_ID;

UPDATE tags
JOIN Duplicates ON TAGGRP_ID = SRCGRP_ID
SET TAGGRP_ID = DSTGRP_ID;

--- ( cont. original Tonda's edit ) not optimal, but we have to avoid duplicates and MySQL doesn't allow same table in subselect
UPDATE Folders main 
JOIN Duplicates ON FDRGRP_ID = SRCGRP_ID
SET FDRGRP_ID = DSTGRP_ID
WHERE NOT EXISTS (SELECT * FROM (SELECT * FROM Folders) dummy WHERE main.FDR_ID = FDR_ID AND DSTGRP_ID = FDRGRP_ID);

-- # CLEANUP #
-- ###########
DELETE FROM EventGroup WHERE GRP_ID IN (SELECT * FROM (select DISTINCT SRCGRP_ID from Duplicates) dummy);
DELETE FROM EventOwner WHERE OWN_ID NOT IN (SELECT GRPOWN_ID FROM EventGroup);
DROP TABLE Duplicates;

-- # create keys:
-- v EventOwner ma byt UNIQUE(OWN_Email)
-- v EventGroup pak UNIQUE(GRPOWN_ID, GrpLink, GrpLinkFolder)
DROP TABLE IF EXISTS EventOwner2;
DROP TABLE IF EXISTS EventOwner_dup;
CREATE TABLE `EventOwner2` like `EventOwner`;
ALTER TABLE EventOwner2 ADD UNIQUE KEY `uOwnEmail` (`OWN_Email`);
insert ignore EventOwner2 select * from EventOwner;
rename table EventOwner to EventOwner_dup;rename table EventOwner2 to EventOwner;
SET FOREIGN_KEY_CHECKS=0;
drop table EventOwner_dup;
SET FOREIGN_KEY_CHECKS=1;

DROP TABLE IF EXISTS EventGroup2;
DROP TABLE IF EXISTS EventGroup_dup;
CREATE TABLE `EventGroup2` like `EventGroup`;
ALTER TABLE EventGroup2 ADD UNIQUE KEY `uGrpOwnId` (`GRPOWN_ID`,`GrpLink`,`GrpLinkFolder`);
insert ignore EventGroup2 select * from EventGroup;
rename table EventGroup to EventGroup_dup;rename table EventGroup2 to EventGroup;
SET FOREIGN_KEY_CHECKS=0;
drop table EventGroup_dup;
SET FOREIGN_KEY_CHECKS=1;
