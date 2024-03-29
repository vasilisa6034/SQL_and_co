-- 0. Добавим столбец с номерами записей в соответствии с их порядком в исходной таблице
ALTER TABLE TABLE1
ADD (NUMERO NUMBER GENERATED BY DEFAULT AS IDENTITY);

-- 1. Заполним пропущенные значения поля BUCKET предыдущими значениями
SELECT COALESCE(a.BUCKET, b.BUCKET) AS BUCKET
FROM TABLE1 a
OUTER apply (
  SELECT BUCKET FROM TABLE1
  WHERE a.BUCKET IS null AND BUCKET IS NOT null AND NUMERO < a.NUMERO 
  ORDER BY NUMERO DESC
  OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY) b
ORDER BY NUMERO;

-- 2. Заполним пропущенные значения полей ADDR_FACT_FLG, ADDR_WORK_FLG, ADDR_REG_FLG по следующей логике: если в соответствующем поле POST_ есть информация, то ставим 1, 
-- если нет - 0
UPDATE TABLE1
SET ADDR_FACT_FLG = 1
WHERE ADDR_FACT_FLG IS NULL AND POST_FACT IS NOT null;

UPDATE TABLE1
SET ADDR_FACT_FLG = 0
WHERE ADDR_FACT_FLG IS NULL AND POST_FACT IS null;

UPDATE TABLE1
SET ADDR_WORK_FLG = 1
WHERE ADDR_WORK_FLG IS NULL AND POST_WORK IS NOT null;

UPDATE TABLE1
SET ADDR_WORK_FLG = 0
WHERE ADDR_WORK_FLG IS NULL AND POST_WORK IS null;

UPDATE TABLE1
SET ADDR_REG_FLG = 1
WHERE ADDR_REG_FLG IS NULL AND POST_REG IS NOT null;

UPDATE TABLE1
SET ADDR_REG_FLG = 0
WHERE ADDR_REG_FLG IS NULL AND POST_REG IS null;

-- 3. Создадим поле "Возраст". Заполним его из соображений, что возраст смотрят на данный момент (09.02.2022), а не на момент выгрузки
ALTER TABLE TABLE1
ADD AGE INTEGER NULL;

UPDATE TABLE1
SET AGE = FLOOR((TRUNC(sysdate)-CAST(BIRTH_DT AS DATE))/365);

-- 4. В поле WORK_START_DT есть некорректные строки: некоторые имеют другой формат (по сути длиннее, чем остальные), некоторые пропущены. Если строка другого формата, 
-- "обрежем" ее до формата (длины) других строк. Пропущенные значения заполним рандомными датами
SELECT LENGTH(WORK_START_DT)
FROM TABLE1
WHERE NUMERO = 1;

UPDATE TABLE1
SET WORK_START_DT = SUBSTR(WORK_START_DT, 0, 19)
WHERE LENGTH(WORK_START_DT) > 19;

UPDATE TABLE1
SET WORK_START_DT = TO_TIMESTAMP(WORK_START_DT, 'DD.MM.YYYY HH24:MI:SS');

ALTER TABLE TABLE1
ADD (NEW_WSD TIMESTAMP(6) NULL);

UPDATE TABLE1
SET NEW_WSD = WORK_START_DT;

ALTER TABLE TABLE1
RENAME COLUMN WORK_START_DT TO OLD_WSD;

ALTER TABLE TABLE1
RENAME COLUMN NEW_WSD TO WORK_START_DT;

UPDATE TABLE1
SET WORK_START_DT = (
  SELECT MIN(WORK_START_DT) + dbms_random.value(0,4)*365
  FROM TABLE1)
WHERE WORK_START_DT IS null;

-- 5. Выясним, на какую дату сделана выгрузка данных (результат: 01.06.18)
SELECT EXPIRE_DT + EXPIRE_DAYS
FROM TABLE1
WHERE EXPIRE_DAYS IS NOT null
OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;

-- 6. Заполним пропущеные значения поля EXPIRE_DAYS. Количество дней возьмем как разность даты выгрузки таблицы и дату истечение срока действия (EXPIRE_DT)
UPDATE TABLE1
SET EXPIRE_DAYS = TO_DATE('01.06.18')-CAST(EXPIRE_DT AS DATE)
WHERE EXPIRE_DAYS IS null;
