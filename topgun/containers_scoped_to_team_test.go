package topgun_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"bytes"

	"strconv"

	"github.com/onsi/gomega/gbytes"
)

var _ = Describe(":life [#136140165] Container scope", func() {
	Context("when the container is scoped to a team", func() {
		BeforeEach(func() {
			Deploy("deployments/concourse.yml")
		})

		It("is only hijackable by someone in that team", func() {
			By("setting a pipeline for team `main`")
			fly.Spawn("set-pipeline", "-n", "-c", "pipelines/get-task-put-waiting.yml", "-p", "container-scope-test")

			By("triggering the build")
			fly.Spawn("unpause-pipeline", "-p", "container-scope-test")
			buildSession := fly.Spawn("trigger-job", "-w", "-j", "container-scope-test/simple-job")
			Eventually(buildSession).Should(gbytes.Say("waiting for /tmp/stop-waiting"))

			By("demonstrating we can hijack into all of the containers")
			buildContainers := containersBy("build #", "1")
			for i := 1; i <= len(buildContainers); i++ {
				hijackSession := spawnFlyInteractive(
					bytes.NewBufferString(strconv.Itoa(i)+"\n"),
					"hijack",
					"-b", "1",
					"hostname",
				)

				<-hijackSession.Exited
				Expect(hijackSession.ExitCode()).To(Equal(0))
			}

			By("creating a separate team")
			setTeamSession := spawnFlyInteractive(
				bytes.NewBufferString("y\n"),
				"set-team",
				"--team-name", "no-access",
				"--local-user", "guest",
			)

			<-setTeamSession.Exited
			Expect(setTeamSession.ExitCode()).To(Equal(0))

			By("logging into other team")
			fly.Spawn("login", "-n", "no-access", "-u", "guest", "-p", "guest")

			By("not allowing hijacking into any containers")
			failedFly := fly.Spawn("hijack", "-b", "1")
			<-failedFly.Exited
			Expect(failedFly.ExitCode()).NotTo(Equal(0))
			Expect(failedFly.Err).To(gbytes.Say("no containers matched your search parameters!"))

			By("logging back into the other team")
			fly.Spawn("login", "-n", "main", "-u", atcUsername, "-p", atcPassword)

			By("stopping the build")
			hijackSession := fly.Spawn(
				"hijack",
				"-b", "1",
				"-s", "simple-task",
				"touch", "/tmp/stop-waiting",
			)

			<-hijackSession.Exited
			Expect(hijackSession.ExitCode()).To(Equal(0))

			Eventually(buildSession).Should(gbytes.Say("done"))
			<-buildSession.Exited
		})
	})
})
