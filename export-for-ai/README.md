# ייצוא ל-NotebookLM

תיקייה זו מכילה קבצי Markdown **מאוחדים** מהקורס, מוכנים להעלאה כ**מקורות** במחברת NotebookLM.

## קבצים

| קובץ | תוכן |
|------|------|
| `00-curriculum-overview.md` | `README.md` + `CURRICULUM.md` בשורש הפרויקט |
| `01-year-1-foundations-master.md` | שנה 1 — יסודות |
| `02-year-2-intermediate-master.md` | שנה 2 — ביניים |
| `03-year-3-clinical-master.md` | שנה 3 — קליני |
| `04-year-4-advanced-master.md` | שנה 4 — מתקדם |
| `05-year-5-mastery-master.md` | שנה 5 — מומחיות |
| `06-case-studies-master.md` | תיאורי מקרה |
| `07-diagnostic-tool-master.md` | כלי אבחון |

סה"כ **8 מקורות** — מתאים בקלות למגבלת המקורות ב-NotebookLM בתוכנית החינמית (50 מקורות למחברת).

## יצירה מחדש

מהשורש של המאגר:

```powershell
.\scripts\Merge-MarkdownForAI.ps1
```

אפשר לציין נתיב מפורש:

```powershell
.\scripts\Merge-MarkdownForAI.ps1 -RepoRoot "C:\path\to\acuponctura" -OutputDir "export-for-ai"
```

הפלט נשמר ב-UTF-8 עם BOM לקריאה נכונה בעברית ב-Windows.

## הנחיות מערכת

ראה **[AI_SYSTEM_PROMPTS.md](AI_SYSTEM_PROMPTS.md)** — טקסטים מוכנים להדבקה ב-NotebookLM.

## NotebookLM — צעדים

1. פתח [NotebookLM](https://notebooklm.google.com) וצור **מחברת חדשה**.
2. ב**מקורות**: העלה את שמונת קבצי ה-`.md` (`00` עד `07`). אין חובה להעלות את `README.md` ו-`AI_SYSTEM_PROMPTS.md` של התיקייה — הם רק הוראות לך.
3. בשדה **הנחיות למחברת** (או המדריך): הדבק את הבלוק הראשון מ-`AI_SYSTEM_PROMPTS.md`.
4. התחל לשאול בצ'אט (אופציונלי: שאלת הפתיחה מאותו קובץ).

## PDF (אופציונלי)

אם נדרש PDF, המר באמצעות עורך Markdown, Pandoc, או כלי אחר — המקור המעודכן תמיד הוא ה-Markdown בפרויקט + הרצת הסקריפט.
