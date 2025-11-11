import { CapacitorConfig } from "@capacitor/cli";


const config: CapacitorConfig = {
appId: "com.civicchatter.app",
appName: "Civic Chatter",
webDir: "../frontend", // points to your existing web app
bundledWebRuntime: false,
server: {
androidScheme: "https"
}
};


export default config;
