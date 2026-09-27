package qa.mentorship;

/** TASK-55.1: артефакт для перевірки стенда — чи справді Maven тягне його з внутрішнього репозиторію. */
public final class DemoLib {
    private DemoLib() {}

    public static String marker() {
        return "qa-demo-lib-from-internal-repository";
    }
}
