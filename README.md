# Pharmacy Inventory Sync Agent (PowerShell)
# وكيل مزامنة مخزون الصيدلية

هذا المشروع مصمم لمزامنة بيانات المنتجات، الأسعار، والمخزون من قاعدة بيانات SQL Server الخاصة بالصيدلية إلى المتجر الإلكتروني عبر API.

## متطلبات التشغيل
* **نظام التشغيل:** Windows 7, Windows 10, Windows 11.
* **قاعدة البيانات:** SQL Server (2008, 2012+, Express).
* **PowerShell:** الإصدار 3.0 أو أحدث (مدمج في ويندوز).

## هيكل المشروع
* `SyncInventory.ps1`: السكربت الأساسي لعملية المزامنة.
* `config.json`: ملف الإعدادات (SQL Server, API, Interval).
* `InstallScheduler.ps1`: سكربت لتثبيت المهمة المجدولة (Windows Task).
* `RunAsAdmin.bat`: ملف لتشغيل المزامنة يدوياً بصلاحيات المسؤول.
* `logs/sync.log`: ملف السجل (يتم إنشاؤه تلقائياً).

## طريقة التثبيت والاستخدام

### 1. إعداد الملف `config.json`
قم بفتح ملف `config.json` وتعديل القيم التالية:
* `sqlServer`: اسم السيرفر (مثلاً `localhost` أو `SERVER\SQLEXPRESS`).
* `database`: اسم قاعدة بيانات الصيدلية.
* `username`: اسم مستخدم SQL Server (sa).
* `password`: كلمة مرور SQL Server.
* `syncIntervalMinutes`: المدة الزمنية بين كل عملية مزامنة (بالدقائق).

### 2. اختبار الاتصال والمزامنة يدوياً
قم بتشغيل ملف `RunAsAdmin.bat` كمسؤول. سيقوم السكربت بـ:
* الاتصال بقاعدة البيانات.
* قراءة المنتجات وحساب إجمالي المخزون من كافة الفروع.
* إرسال البيانات إلى الـ API.
* عرض النتيجة في الشاشة وتسجيلها في ملف `logs/sync.log`.

### 3. تثبيت المجدول التلقائي (Scheduler)
لجعل السكربت يعمل تلقائياً كل فترة محددة:
1. انقر بزر الماوس الأيمن على `InstallScheduler.ps1`.
2. اختر `Run with PowerShell`.
3. سيقوم السكربت بإنشاء مهمة في Windows Task Scheduler باسم `PharmacyInventorySync`.

### 4. إزالة المجدول التلقائي
لإزالة المهمة المجدولة، قم بتشغيل PowerShell كمسؤول ونفذ الأمر التالي:
```powershell
schtasks /delete /tn "PharmacyInventorySync" /f
```

## تفاصيل الربط (Mapping)
بناءً على تحليل قاعدة البيانات، يتم جلب البيانات كالتالي:
* **كود المنتج (Code):** `product_code`
* **الاسم (Name):** الاسم الإنجليزي `product_name_en` (أو العربي إذا كان الإنجليزي فارغاً).
* **السعر (Price):** `sell_price`
* **الكمية (Quantity):** مجموع `amount` من جدول `Product_Amount` لجميع المخازن والفروع.
* **الباركود (Barcode):** الباركود الدولي `product_int_code`.

## الدعم الفني والأخطاء
في حال حدوث خطأ:
1. راجع ملف `logs/sync.log` للحصول على تفاصيل الخطأ (Exception Stack Trace).
2. تأكد من صحة بيانات الاتصال في `config.json`.
3. تأكد من أن مستخدم SQL لديه صلاحية القراءة على جداول `Products` و `Product_Amount`.
